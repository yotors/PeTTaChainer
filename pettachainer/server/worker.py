import math
import multiprocessing as mp
import os
from pathlib import Path
import resource
import tempfile
import traceback
from typing import Any
import uuid

from sexpdata import Symbol, dumps, loads


class WorkerError(RuntimeError):
    pass


class WorkerTimeout(WorkerError):
    pass


def _limit_process(memory_mb: int, cpu_seconds: float, max_files: int, work_dir: str) -> None:
    memory_bytes = memory_mb * 1024 * 1024
    cpu_limit = max(1, math.ceil(cpu_seconds))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024 * 1024, 16 * 1024 * 1024))
    resource.setrlimit(resource.RLIMIT_NOFILE, (max_files, max_files))
    resource.setrlimit(resource.RLIMIT_CPU, (cpu_limit, cpu_limit + 1))
    resource.setrlimit(resource.RLIMIT_AS, (memory_bytes, memory_bytes))
    os.chdir(work_dir)
    os.environ.update({"HOME": work_dir, "TMPDIR": work_dir})


def _strings(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    return [str(value)]


def _between(results: list[str], start: str, end: str) -> list[str]:
    try:
        start_index = results.index(start) + 1
        end_index = results.index(end, start_index)
    except ValueError as exc:
        raise RuntimeError("PeTTa job markers were not returned") from exc
    return results[start_index:end_index]


def _internal_query_goal(query: str) -> str:
    parsed = loads(query)
    if not isinstance(parsed, list) or len(parsed) != 4 or str(parsed[0]) != ":":
        raise ValueError("query must have the form (: proof pattern truth-value)")
    _, proof, pattern, truth_value = parsed
    return dumps(
        [pattern, [Symbol("workerKb"), Symbol("MAIN"), Symbol("Nil")], proof, truth_value]
    )


def _collapsed_internal_results(values: list[str]) -> list[str]:
    if not values:
        return []
    if len(values) != 1:
        raise RuntimeError("PeTTa returned an invalid collapsed chainer result")
    parsed = loads(values[0])
    if not isinstance(parsed, list):
        raise RuntimeError("PeTTa returned a non-list chainer result")
    if (
        len(parsed) == 1
        and isinstance(parsed[0], list)
        and (not parsed[0] or isinstance(parsed[0][0], list))
    ):
        parsed = parsed[0]
    external: list[str] = []
    for item in parsed:
        if not isinstance(item, list) or len(item) != 4:
            raise RuntimeError("PeTTa returned an invalid internal proof atom")
        pattern, _kb, proof, truth_value = item
        external.append(dumps([Symbol(":"), proof, pattern, truth_value]))
    return external


def _is_variable(term: Any) -> bool:
    return isinstance(term, Symbol) and str(term).startswith("$")


def _substitute(term: Any, bindings: dict[str, Any]) -> Any:
    if _is_variable(term):
        return bindings.get(str(term), term)
    if isinstance(term, list):
        return [_substitute(item, bindings) for item in term]
    return term


def _unify(pattern: Any, value: Any, bindings: dict[str, Any]) -> dict[str, Any] | None:
    if _is_variable(pattern):
        name = str(pattern)
        if name in bindings:
            return _unify(bindings[name], value, bindings)
        return {**bindings, name: value}
    if _is_variable(value):
        return _unify(value, pattern, bindings)
    if isinstance(pattern, list) and isinstance(value, list) and len(pattern) == len(value):
        current = bindings
        for left, right in zip(pattern, value, strict=True):
            current = _unify(left, right, current)
            if current is None:
                return None
        return current
    return bindings if pattern == value else None


def _truth_value(value: Any) -> tuple[float, float] | None:
    if isinstance(value, list) and len(value) == 3 and str(value[0]) == "STV":
        try:
            return float(value[1]), float(value[2])
        except (TypeError, ValueError):
            return None
    return None


def _rule_truth(rule_tv: Any, premise_tvs: list[Any]) -> Any:
    parsed = [_truth_value(rule_tv), *(_truth_value(value) for value in premise_tvs)]
    if any(value is None for value in parsed):
        return rule_tv
    values = [value for value in parsed if value is not None]
    strength = math.prod(value[0] for value in values)
    confidence = min(value[1] for value in values)
    return [Symbol("STV"), strength, confidence]


def _horn_reason(job: dict[str, Any]) -> list[str]:
    facts: list[tuple[Any, Any, Any]] = []
    rules: list[tuple[Any, list[Any], list[Any], Any]] = []
    seen: set[str] = set()
    for item in job["statements"]:
        statement = loads(item["source"])
        if not isinstance(statement, list) or len(statement) != 4 or str(statement[0]) != ":":
            continue
        _, proof, body, tv = statement
        if isinstance(body, list) and len(body) == 3 and str(body[0]) in {"Implication", "BiImplication"}:
            premises, conclusions = body[1], body[2]
            if (
                isinstance(premises, list)
                and premises
                and str(premises[0]) == "Premises"
                and isinstance(conclusions, list)
                and conclusions
                and str(conclusions[0]) == "Conclusions"
            ):
                rules.append((proof, premises[1:], conclusions[1:], tv))
                if str(body[0]) == "BiImplication":
                    rules.append((proof, conclusions[1:], premises[1:], tv))
        else:
            key = dumps(body)
            if key not in seen:
                seen.add(key)
                facts.append((body, proof, tv))

    if job.get("seed_terms"):
        seeds = [loads(seed) for seed in job["seed_terms"]]
        facts = [
            fact
            for fact in facts
            if any(_unify(seed, fact[0], {}) is not None for seed in seeds)
        ]
        seen = {dumps(fact[0]) for fact in facts}

    for _ in range(max(0, int(job.get("steps", 0)))):
        changed = False
        for rule_proof, premises, conclusions, rule_tv in rules:
            matches: list[tuple[dict[str, Any], list[Any], list[Any]]] = [({}, [], [])]
            for premise in premises:
                next_matches: list[tuple[dict[str, Any], list[Any], list[Any]]] = []
                for bindings, proofs, tvs in matches:
                    for fact, fact_proof, fact_tv in facts:
                        unified = _unify(_substitute(premise, bindings), fact, bindings)
                        if unified is not None:
                            next_matches.append((unified, [*proofs, fact_proof], [*tvs, fact_tv]))
                matches = next_matches
                if not matches:
                    break
            for bindings, proofs, tvs in matches:
                proof = [Symbol("rule-proof"), rule_proof, *proofs]
                tv = _rule_truth(rule_tv, tvs)
                for conclusion in conclusions:
                    fact = _substitute(conclusion, bindings)
                    key = dumps(fact)
                    if key not in seen:
                        seen.add(key)
                        facts.append((fact, proof, tv))
                        changed = True
        if not changed:
            break

    query = loads(job["query"])
    _, _query_proof, pattern, _query_tv = query
    results: list[str] = []
    for fact, proof, tv in facts:
        bindings = _unify(pattern, fact, {})
        if bindings is not None:
            results.append(dumps([Symbol(":"), proof, _substitute(pattern, bindings), tv]))
    return results


def _reasoning_job(job: dict[str, Any], work_dir: str) -> dict[str, Any]:
    from petta import PeTTa

    metta_dir = Path(__file__).resolve().parents[1] / "metta"
    logic_path = metta_dir / "logic_configs" / f"{job.get('logic_config', 'pln')}.metta"
    if not logic_path.is_file():
        raise ValueError("unsupported logic configuration")

    token = f"worker-marker-{uuid.uuid4().hex}"
    query_marker = f"({token} query)"
    end_marker = f"({token} end)"
    lines = ["!(import! &self petta_chainer)"]
    adds = [
        f"!({'compileadd-mine' if item['mine_patterns'] else 'compileadd'} workerKb {item['source']})"
        for item in job["statements"]
    ]
    lines.extend(adds)

    if job["operation"] == "backward":
        goal = _internal_query_goal(job["query"])
        lines.extend(
            [
                f"!{query_marker}",
                f"!(collapse (chainer {job['steps']} {goal}))",
                f"!{end_marker}",
            ]
        )
    else:
        forward_marker = f"({token} forward)"
        seeds = job.get("seed_terms")
        if not seeds:
            forward_expr = f"(forward-chain {job['steps']} workerKb)"
        elif len(seeds) == 1:
            forward_expr = f"(forward-chain-from {job['steps']} workerKb {seeds[0]})"
        else:
            bindings = " ".join(
                f"($seed{index} (forward-select-fact workerKb {seed}))"
                for index, seed in enumerate(seeds)
            )
            selected = " ".join(f"$seed{index}" for index in range(len(seeds)))
            forward_expr = (
                f"(let* ({bindings}) "
                f"(forward-chain-from-facts {job['steps']} workerKb ({selected})))"
            )
        lines.extend([f"!{forward_marker}", f"!{forward_expr}", f"!{query_marker}"])
        if job.get("query"):
            goal = _internal_query_goal(job["query"])
            lines.append(f"!(collapse (chainer {job['query_steps']} {goal}))")
        lines.append(f"!{end_marker}")

    job_path = Path(work_dir) / "request.metta"
    for source in metta_dir.iterdir():
        target = Path(work_dir) / source.name
        if target.name != job_path.name:
            target.symlink_to(source, target_is_directory=source.is_dir())
    job_path.write_text("\n\n".join(lines) + "\n", encoding="utf-8")
    results = _strings(PeTTa().load_metta_file(str(job_path)))

    if job["operation"] == "backward":
        query_results = _collapsed_internal_results(_between(results, query_marker, end_marker))
        return {"results": query_results or _horn_reason(job)}
    query_results = None
    if job.get("query"):
        query_results = _collapsed_internal_results(_between(results, query_marker, end_marker))
        if not query_results:
            fallback_job = {**job, "steps": job["steps"]}
            query_results = _horn_reason(fallback_job)
    return {
        "forward_result": _between(results, forward_marker, query_marker),
        "query_results": query_results,
    }


def _execute(job: dict[str, Any], work_dir: str) -> dict[str, Any]:
    operation = job["operation"]
    if operation in {"backward", "forward"}:
        return _reasoning_job(job, work_dir)

    from pettachainer import PeTTaChainer, check_query, check_stmt

    handler = PeTTaChainer(logic_config=job.get("logic_config", "pln"))

    if operation in {"validate", "validate_statements"}:
        sources = job["sources"] if operation == "validate_statements" else [job["source"]]
        evaluated_sources = []
        for source in sources:
            evaluated = (
                handler.evaluate_statement(source)
                if operation == "validate_statements" or job["kind"] == "statement"
                else handler.evaluate_query(source)
            )
            checker = (
                check_stmt
                if operation == "validate_statements" or job["kind"] == "statement"
                else check_query
            )
            if checker(evaluated) == 0.0:
                kind = "statement" if operation == "validate_statements" else job["kind"]
                raise ValueError(f"PeTTa rejected the evaluated {kind}")
            evaluated_sources.append(evaluated)
        return {
            "evaluated": evaluated_sources
            if operation == "validate_statements"
            else evaluated_sources[0]
        }

    raise ValueError(f"unsupported worker operation: {operation}")


def _worker_entry(job: dict[str, Any], limits: dict[str, Any], conn, work_dir: str) -> None:
    try:
        _limit_process(
            memory_mb=limits["memory_mb"],
            cpu_seconds=limits["timeout_seconds"],
            max_files=limits["max_files"],
            work_dir=work_dir,
        )
        conn.send({"status": "ok", "payload": _execute(job, work_dir)})
    except BaseException as exc:
        try:
            conn.send(
                {
                    "status": "error",
                    "error_type": exc.__class__.__name__,
                    "message": str(exc),
                    "traceback": traceback.format_exc(limit=20),
                }
            )
        except Exception:
            pass
    finally:
        conn.close()


def run_worker(job: dict[str, Any], *, timeout_seconds: float, memory_mb: int, max_files: int) -> dict[str, Any]:
    context = mp.get_context("spawn")
    parent, child = context.Pipe(duplex=False)
    with tempfile.TemporaryDirectory(prefix="pettachainer-worker-") as work_dir:
        process = context.Process(
            target=_worker_entry,
            args=(
                job,
                {
                    "timeout_seconds": timeout_seconds,
                    "memory_mb": memory_mb,
                    "max_files": max_files,
                },
                child,
                work_dir,
            ),
            daemon=True,
        )
        process.start()
        child.close()
        try:
            if not parent.poll(timeout_seconds):
                process.terminate()
                process.join(2)
                if process.is_alive():
                    process.kill()
                    process.join()
                raise WorkerTimeout(f"reasoning exceeded the {timeout_seconds:g} second limit")
            try:
                response = parent.recv()
            except EOFError as exc:
                process.join()
                raise WorkerError(f"worker exited without a response (exit code {process.exitcode})") from exc
            process.join(2)
        finally:
            parent.close()
            if process.is_alive():
                process.kill()
                process.join()

    if response["status"] == "ok":
        return response["payload"]
    raise WorkerError(f"{response['error_type']}: {response['message']}")
