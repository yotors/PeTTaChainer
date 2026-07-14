import re
from dataclasses import dataclass

from sexpdata import Symbol, loads


class PolicyViolation(ValueError):
    pass


@dataclass(frozen=True)
class ParsedStatement:
    source: str
    kind: str


_SYMBOL = re.compile(r"^[^\s()\"';]+$")
_BLOCKED_HEADS = {
    "!",
    "CPU",
    "Predicate",
    "add-atom",
    "assertzPredicate",
    "bind!",
    "call",
    "callPredicate",
    "case",
    "catch",
    "change-state!",
    "collapse",
    "eval",
    "get-atoms",
    "import!",
    "import_prolog_function",
    "import_prolog_functions_from_file",
    "let",
    "let*",
    "load-ascii",
    "load-file",
    "match",
    "pragma!",
    "progn",
    "py-eval",
    "remove-all-atoms",
    "remove-atom",
    "superpose",
    "transfer!",
    "translatePredicate",
}
_SAFE_COMPUTE_FUNCTIONS = {
    "+",
    "-",
    "*",
    "/",
    "%",
    "pow-math",
    "sqrt-math",
    "abs-math",
    "min-atom",
    "max-atom",
}
_TV_HEADS = {
    "STV",
    "NatDist",
    "FloatDist",
    "ParticleDist",
    "PointMass",
    "ParticleFromNormal",
    "ParticleFromPairs",
}


def _symbol(value, where: str) -> str:
    if not isinstance(value, Symbol):
        raise PolicyViolation(f"{where} must be a symbol")
    text = value.value()
    if not _SYMBOL.fullmatch(text):
        raise PolicyViolation(f"invalid symbol in {where}")
    return text


def _parse_one(source: str):
    if "\x00" in source:
        raise PolicyViolation("NUL bytes are not allowed")
    try:
        value = loads(source)
    except Exception as exc:
        raise PolicyViolation(f"invalid S-expression: {exc}") from exc
    if not isinstance(value, list):
        raise PolicyViolation("the input must be one S-expression")
    return value


def _validate_data(term, depth: int = 0) -> None:
    if depth > 64:
        raise PolicyViolation("expression nesting exceeds 64 levels")
    if isinstance(term, (int, float, str)):
        return
    if isinstance(term, Symbol):
        text = _symbol(term, "term")
        if text in _BLOCKED_HEADS or text.endswith("!"):
            raise PolicyViolation(f"symbol {text!r} is not allowed")
        return
    if not isinstance(term, list) or not term:
        raise PolicyViolation("empty expressions are not allowed here")
    head = _symbol(term[0], "expression head")
    if head.startswith("$"):
        raise PolicyViolation("variable expression heads are not allowed")
    if head in _BLOCKED_HEADS or head.endswith("!"):
        raise PolicyViolation(f"expression {head!r} is not allowed")
    if head in {"Compute", "MapDist", "Map2Dist"}:
        if len(term) < 3:
            raise PolicyViolation(f"{head} is incomplete")
        function = _symbol(term[1], f"{head} function")
        if function not in _SAFE_COMPUTE_FUNCTIONS:
            raise PolicyViolation(f"compute function {function!r} is not allowed")
    for child in term[1:]:
        _validate_data(child, depth + 1)


def _validate_tv(term, allow_variable: bool) -> None:
    if isinstance(term, Symbol) and term.value().startswith("$"):
        if allow_variable:
            return
        raise PolicyViolation("statement truth values cannot be variables")
    if not isinstance(term, list) or not term:
        raise PolicyViolation("truth value must be a supported expression")
    head = _symbol(term[0], "truth-value head")
    if head not in _TV_HEADS:
        raise PolicyViolation(f"truth-value constructor {head!r} is not supported")
    for child in term[1:]:
        _validate_data(child)


def _variables(term) -> set[str]:
    if isinstance(term, Symbol):
        text = term.value()
        return {text} if text.startswith("$") else set()
    if isinstance(term, list):
        result: set[str] = set()
        for child in term:
            result.update(_variables(child))
        return result
    return set()


def _validate_implication(term: list) -> str:
    head = _symbol(term[0], "rule head")
    if head not in {"Implication", "BiImplication"} or len(term) != 3:
        raise PolicyViolation("invalid implication structure")
    premises, conclusions = term[1], term[2]
    if not isinstance(premises, list) or not premises or _symbol(premises[0], "premises head") != "Premises":
        raise PolicyViolation("rules require a Premises expression")
    if not isinstance(conclusions, list) or not conclusions or _symbol(conclusions[0], "conclusions head") != "Conclusions":
        raise PolicyViolation("rules require a Conclusions expression")
    if len(premises) == 1 or len(conclusions) == 1:
        raise PolicyViolation("premises and conclusions cannot be empty")
    for child in premises[1:] + conclusions[1:]:
        _validate_data(child)
    premise_variables = _variables(premises[1:])
    conclusion_variables = _variables(conclusions[1:])
    if not conclusion_variables.issubset(premise_variables):
        raise PolicyViolation("every conclusion variable must be bound by a premise")
    if head == "BiImplication" and premise_variables != conclusion_variables:
        raise PolicyViolation("bidirectional rules require the same variables on both sides")
    return "bidirectional_rule" if head == "BiImplication" else "rule"


def validate_statement_source(source: str, max_chars: int) -> ParsedStatement:
    source = source.strip()
    if not source or len(source) > max_chars:
        raise PolicyViolation(f"statement length must be between 1 and {max_chars} characters")
    term = _parse_one(source)
    if len(term) != 4 or _symbol(term[0], "statement head") != ":":
        raise PolicyViolation("a statement must have the form (: proof-id type truth-value)")
    proof = _symbol(term[1], "proof id")
    if proof.startswith("$"):
        raise PolicyViolation("statement proof ids cannot be variables")
    type_term = term[2]
    if not isinstance(type_term, list) or not type_term:
        raise PolicyViolation("statement type must be a non-empty expression")
    type_head = _symbol(type_term[0], "statement type head")
    kind = _validate_implication(type_term) if type_head in {"Implication", "BiImplication"} else "fact"
    if kind == "fact":
        _validate_data(type_term)
        if _variables(type_term):
            raise PolicyViolation("facts must be ground and cannot contain variables")
    _validate_tv(term[3], allow_variable=False)
    return ParsedStatement(source=source, kind=kind)


def validate_query_source(source: str, max_chars: int) -> str:
    source = source.strip()
    if not source or len(source) > max_chars:
        raise PolicyViolation(f"query length must be between 1 and {max_chars} characters")
    term = _parse_one(source)
    if len(term) != 4 or _symbol(term[0], "query head") != ":":
        raise PolicyViolation("a query must have the form (: $proof type $truth-value)")
    if not _symbol(term[1], "query proof").startswith("$"):
        raise PolicyViolation("query proof must be a variable")
    _validate_data(term[2])
    _validate_tv(term[3], allow_variable=True)
    return source


def validate_seed_term(source: str, max_chars: int) -> str:
    source = source.strip()
    if not source or len(source) > max_chars:
        raise PolicyViolation(f"seed length must be between 1 and {max_chars} characters")
    term = _parse_one(source)
    _validate_data(term)
    return source
