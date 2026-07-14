from pettachainer.server.worker import _horn_reason, run_worker


def test_worker_validates_in_an_isolated_process():
    result = run_worker(
        {
            "operation": "validate",
            "kind": "statement",
            "source": "(: dog (Dog fido) (STV 1.0 1.0))",
            "logic_config": "pln",
        },
        timeout_seconds=10,
        memory_mb=1024,
        max_files=64,
    )

    assert result["evaluated"] == "(: dog (Dog fido) (STV 1.0 1.0))"


def test_worker_reconstructs_kb_and_runs_backward_reasoning():
    result = run_worker(
        {
            "operation": "backward",
            "logic_config": "pln",
            "statements": [
                {"source": "(: dog (Dog fido) (STV 1.0 1.0))", "mine_patterns": False}
            ],
            "query": "(: $proof (Dog fido) $tv)",
            "steps": 20,
        },
        timeout_seconds=10,
        memory_mb=1024,
        max_files=64,
    )

    assert result["results"]
    assert "Dog fido" in result["results"][0]


def test_worker_runs_forward_then_queries_materialized_state():
    result = run_worker(
        {
            "operation": "forward",
            "logic_config": "pln",
            "statements": [
                {"source": "(: dog (Dog fido) (STV 1.0 1.0))", "mine_patterns": False},
                {
                    "source": "(: dog-animal (Implication (Premises (Dog $x)) (Conclusions (Animal $x))) (STV 1.0 1.0))",
                    "mine_patterns": False,
                },
            ],
            "steps": 20,
            "seed_terms": None,
            "query": "(: $proof (Animal fido) $tv)",
            "query_steps": 20,
        },
        timeout_seconds=10,
        memory_mb=1024,
        max_files=64,
    )

    assert "true" in result["forward_result"]
    assert result["query_results"]
    assert "Animal fido" in result["query_results"][0]


def test_horn_fallback_reaches_recursive_multi_premise_closure():
    results = _horn_reason(
        {
            "statements": [
                {"source": "(: ab (Edge A B) (STV 1.0 1.0))"},
                {"source": "(: bc (Edge B C) (STV 1.0 1.0))"},
                {
                    "source": "(: base (Implication (Premises (Edge $x $y)) (Conclusions (Path $x $y))) (STV 1.0 1.0))"
                },
                {
                    "source": "(: step (Implication (Premises (Path $x $y) (Edge $y $z)) (Conclusions (Path $x $z))) (STV 1.0 1.0))"
                },
            ],
            "query": "(: $proof (Path A $where) $tv)",
            "steps": 10,
        }
    )

    assert any("(Path A C)" in result for result in results)


def test_horn_fallback_honors_forward_seed_selection():
    results = _horn_reason(
        {
            "statements": [
                {"source": "(: a (Source A) (STV 1.0 1.0))"},
                {"source": "(: b (Source B) (STV 1.0 1.0))"},
                {
                    "source": "(: derive (Implication (Premises (Source $x)) (Conclusions (Result $x))) (STV 1.0 1.0))"
                },
            ],
            "query": "(: $proof (Result $x) $tv)",
            "seed_terms": ["(Source B)"],
            "steps": 10,
        }
    )

    assert len(results) == 1
    assert "(Result B)" in results[0]
