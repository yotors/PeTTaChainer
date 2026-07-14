import pytest

from pettachainer.server.policy import (
    PolicyViolation,
    validate_query_source,
    validate_seed_term,
    validate_statement_source,
)


def test_classifies_facts_and_rules():
    fact = validate_statement_source("(: dog (Dog fido) (STV 1.0 1.0))", 1000)
    rule = validate_statement_source(
        "(: dog-animal (Implication (Premises (Dog $x)) (Conclusions (Animal $x))) (STV 1.0 1.0))",
        1000,
    )

    assert fact.kind == "fact"
    assert rule.kind == "rule"


def test_accepts_queries_and_seed_terms():
    assert validate_query_source("(: $proof (Animal $x) $tv)", 1000)
    assert validate_seed_term("(Dog fido)", 1000) == "(Dog fido)"


@pytest.mark.parametrize(
    "source",
    [
        '(: bad (eval (py-eval "open socket")) (STV 1.0 1.0))',
        "(: bad (import! &self secrets) (STV 1.0 1.0))",
        "(: bad (CPU halt ()) (STV 1.0 1.0))",
        "(: bad (Compute halt (1) -> $x) (STV 1.0 1.0))",
        "(: $proof (Dog fido) (STV 1.0 1.0))",
    ],
)
def test_rejects_executable_or_invalid_statements(source):
    with pytest.raises(PolicyViolation):
        validate_statement_source(source, 1000)


def test_rejects_multiple_expressions():
    with pytest.raises(PolicyViolation):
        validate_statement_source(
            "(: a (A) (STV 1 1)) (: b (B) (STV 1 1))",
            1000,
        )


@pytest.mark.parametrize(
    "source",
    [
        "(: open-fact (Dog $x) (STV 1.0 1.0))",
        "(: unsafe (Implication (Premises (Dog $x)) (Conclusions (Likes $x $y))) (STV 1.0 1.0))",
        "(: unsafe-bi (BiImplication (Premises (Parent $x $y)) (Conclusions (Person $x))) (STV 1.0 1.0))",
    ],
)
def test_rejects_non_ground_facts_and_unbound_rule_variables(source):
    with pytest.raises(PolicyViolation):
        validate_statement_source(source, 1000)
