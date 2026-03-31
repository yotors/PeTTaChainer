import logging
import multiprocessing as mp
from pathlib import Path
import threading
import traceback
import uuid
from typing import List, Optional

from petta import PeTTa

from .pln_validator import check_query, check_stmt

logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

LOADEDLIB = False
LOADED_LOCK = threading.Lock()


def get_language_spec(llm_focused: bool = True) -> str:
    return (Path(__file__).resolve().parent / ("LLM_RULE_SPEC.md" if llm_focused else "LANGUAGE_SPEC.md")).read_text(encoding="utf-8")


def _query_worker(handler: PeTTa, kb: str, steps: int, atom: str, conn):
    try:
        atoms = handler.process_metta_string(f"!(query {steps} {kb} {atom})")
        conn.send(("ok", atoms))
    except Exception as exc:  # pragma: no cover
        conn.send(("err", (exc.__class__.__name__, str(exc), traceback.format_exc())))
    finally:
        conn.close()


def _as_list(value) -> List[str]:
    return [value] if isinstance(value, str) else value


class PeTTaChainer:
    def __init__(self):
        global LOADEDLIB
        self.handler = PeTTa()
        self.kb = f"kb{uuid.uuid4().hex}"
        base_dir = Path(__file__).resolve().parent

        if LOADEDLIB:
            return
        with LOADED_LOCK:
            if LOADEDLIB:
                return
            metta_path = base_dir / "metta" / "petta_chainer.metta"
            logger.info("Loading MeTTa library from %s", metta_path)
            self.handler.load_metta_file(str(metta_path))
            LOADEDLIB = True

    def _evaluate(self, atom: str) -> str:
        result = self.handler.process_metta_string(f"!(eval {atom})")
        if isinstance(result, list):
            if not result:
                raise ValueError("PeTTa returned no results")
            result = result[0]
        return str(result).strip()

    @staticmethod
    def _validate(kind: str, raw_atom: str, evaluated_atom: str, checker) -> None:
        if checker(evaluated_atom) == 0.0:
            raise ValueError(
                f"Invalid evaluated PLN {kind}. input={raw_atom} evaluated={evaluated_atom}"
            )

    def add_atom(self, atom: str) -> str:
        evaluated_atom = self._evaluate(atom)
        self._validate("statement", atom, evaluated_atom, check_stmt)
        return self.handler.process_metta_string(f"!(compileadd {self.kb} {evaluated_atom})")

    def add_atoms_no_check(self, atoms: List[str]) -> str:
        adds = [f"(compileadd {self.kb} {atom})" for atom in atoms]
        return self.handler.process_metta_string(
            f"!(superpose ({' '.join(adds)}))"
        )

    evaluate_statement = _evaluate
    evaluate_query = _evaluate

    def print_kb(self):
        for atom in _as_list(self.handler.process_metta_string(f"!(match &kb $a (pretty $a))")):
            print(atom)

    def query(self, atom: str, steps: int = 100, timeout_sec: Optional[float] = 10) -> List[str]:
        evaluated_query = self._evaluate(atom)
        self._validate("query", atom, evaluated_query, check_query)

        if timeout_sec is None or timeout_sec <= 0:
            return _as_list(
                self.handler.process_metta_string(f"!(query {steps} {self.kb} {evaluated_query})")
            )

        # Use a forked process so timeout can actually stop CPU-bound query work.
        ctx = mp.get_context("fork")
        parent_conn, child_conn = ctx.Pipe(duplex=False)
        worker = ctx.Process(
            target=_query_worker,
            args=(self.handler, self.kb, steps, evaluated_query, child_conn),
            daemon=True,
        )
        worker.start()
        child_conn.close()
        worker.join(timeout_sec)

        if worker.is_alive():
            worker.terminate()
            worker.join()
            parent_conn.close()
            raise TimeoutError(f"PeTTa query timed out after {timeout_sec} seconds")

        try:
            if not parent_conn.poll():
                raise RuntimeError("PeTTa query worker exited without returning a result")
            status, payload = parent_conn.recv()
            if status == "ok":
                return payload
            err_type, err_msg, err_tb = payload
            raise RuntimeError(f"PeTTa query worker failed [{err_type}]: {err_msg}\n{err_tb}")
        finally:
            parent_conn.close()

    language_spec = staticmethod(get_language_spec)


if __name__ == "__main__":
    handler = PeTTaChainer()
    for atom in (
        "(: fact_a (Count A 1) (STV 1.0 1.0))",
        "(: fact_b (Count B 2) (STV 1.0 1.0))",
        "(: sum_rule (Implication (Premises (Count A $a) (Count B $b) (Compute + ($a $b) -> $c)) (Conclusions (Count C $c))) (STV 1.0 1.0))",
    ):
        print(f"Adding {atom}")
        print(handler.add_atom(atom))
    print("Query result:")
    print(handler.query("(: $prf (Count C $c) $tv)"))
