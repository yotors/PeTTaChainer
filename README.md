To install, clone this repo and its dependency into the same directory:

```bash
git clone https://github.com/patham9/PeTTa.git
git clone https://github.com/rTreutlein/PeTTaChainer.git
```

These are independent repositories placed next to each other because
PeTTaChainer depends on PeTTa. The Docker build context is their parent
directory, while `PeTTaChainer/Dockerfile.dockerignore` admits only those two
repositories; no Mindplex or other workspace directories are assumed.

## Headless API server

The server stores source facts and rules in PostgreSQL and reconstructs a fresh,
resource-limited PeTTa process for every reasoning request. The AtomSpace and
forward-derived facts are execution state, not durable storage.

For the currently regressed native PeTTaChainer rule-query paths, the worker
falls back to a bounded deterministic Horn closure over the same validated
statements. That compatibility path supports ground facts, range-restricted
`Implication`/`BiImplication` rules, multiple premises and conclusions,
recursive closure, variable queries, and forward seed selection. For `STV`
values it multiplies premise/rule strengths and uses the minimum confidence.
It is deliberately not presented as full PLN: distribution-valued formulas,
mining, and compute premises still require a successful native PeTTa result.
The fallback can be removed once the native forward and open-query regressions
are fixed and covered by the server worker tests.

Requirements:

- Docker with Compose
- a random PostgreSQL password
- an API key secret containing at least 32 characters

Start a local server:

```bash
cp .env.example .env
# Replace both example secrets in .env before continuing.
docker compose up --build
```

Keep secret values single-quoted in `.env`. Docker Compose otherwise treats a
`$NAME` sequence inside an unquoted password as variable interpolation. The
database connection is assembled from separate fields, so other reserved
characters such as `@`, `:`, `/`, `%`, and `|` need no URL escaping.

The API binds to `127.0.0.1:8000` by default. Put a TLS-terminating reverse
proxy in front of it before exposing it outside the host. API key entries use
`owner-id:secret`; clients send only the secret as a bearer token. Multiple
entries are comma-separated and may use the same owner id during key rotation.
`PETTACHAINER_API_KEYS` is the server's inbound access list: you generate and
set these secrets in `.env`, then give a secret to each authorized API client.
It is not a credential that this server uses to call another service. For
example:

```dotenv
PETTACHAINER_API_KEYS=local-admin:LONG_RANDOM_SECRET,automation:ANOTHER_LONG_RANDOM_SECRET
```

`PETTACHAINER_ALLOWED_HOSTS` is also comma-separated because a deployment may
accept more than one HTTP host name, for example
`api.example.com,localhost`. These are the only two list-valued settings.

Create a knowledge base:

```bash
curl -sS http://127.0.0.1:8000/v1/knowledge-bases \
  -H 'Authorization: Bearer YOUR_SECRET' \
  -H 'Content-Type: application/json' \
  -d '{"name":"animals","logic_config":"pln"}'
```

Add a fact or rule using the returned knowledge-base id:

```bash
curl -sS http://127.0.0.1:8000/v1/knowledge-bases/KB_ID/statements \
  -H 'Authorization: Bearer YOUR_SECRET' \
  -H 'Idempotency-Key: dog-fido-v1' \
  -H 'Content-Type: application/json' \
  -d '{"source":"(: dog-fido (Dog fido) (STV 1.0 1.0))"}'
```

Add many statements atomically. Each item has its own idempotency key, and a
retry returns the previously created statements without advancing the
knowledge-base revision:

```bash
curl -sS http://127.0.0.1:8000/v1/knowledge-bases/KB_ID/statements/bulk \
  -H 'Authorization: Bearer YOUR_SECRET' \
  -H 'Content-Type: application/json' \
  -d '{"statements":[
    {"source":"(: dog-fido (Dog fido) (STV 1.0 1.0))","idempotency_key":"dog-fido-v1"},
    {"source":"(: cat-milo (Cat milo) (STV 1.0 1.0))","idempotency_key":"cat-milo-v1"}
  ]}'
```

Run a backward query:

```bash
curl -sS http://127.0.0.1:8000/v1/knowledge-bases/KB_ID/reason/backward \
  -H 'Authorization: Bearer YOUR_SECRET' \
  -H 'Content-Type: application/json' \
  -d '{"query":"(: $proof (Dog fido) $tv)","steps":100}'
```

Run forward chaining and optionally query the materialized state in the same
isolated operation:

```bash
curl -sS http://127.0.0.1:8000/v1/knowledge-bases/KB_ID/reason/forward \
  -H 'Authorization: Bearer YOUR_SECRET' \
  -H 'Content-Type: application/json' \
  -d '{"steps":100,"query":"(: $proof (Animal fido) $tv)","query_steps":100}'
```

Available routes are described by `/openapi.json`. Interactive documentation
is available at `/docs` outside production mode.

### Persistence and mutation semantics

PostgreSQL is authoritative. Every accepted statement has a UUID, an
idempotency key, and the knowledge-base revision at which it was added. The
event table provides an ordered mutation history. Repeating an add request
with the same idempotency key returns the original statement.

Individual fact/rule removal is intentionally not exposed in this version.
Deleting an entire knowledge base is supported. Statement removal will be
added only with rebuild-and-invalidation tests that prove forward-derived
facts and compiled rules cannot survive the deletion.

### Security boundary

The public API accepts the documented PLN data grammar, not arbitrary MeTTa.
Imports, evaluation, Prolog/Python calls, state mutation forms, dynamic
expression heads, and unapproved compute functions are rejected before PeTTa
runs. Accepted input is still evaluated in a fresh subprocess with wall-clock,
CPU, address-space, file-size, and file-descriptor limits.

The Compose deployment additionally runs as a non-root user, drops Linux
capabilities, enables `no-new-privileges`, uses a read-only root filesystem,
and limits memory and process count. Production deployments should also apply
TLS, ingress body/rate limits, database backups, centralized logs, and a
container-runtime seccomp/AppArmor policy.

Configuration is supplied with `PETTACHAINER_` environment variables. Useful
limits include `WORKER_TIMEOUT_SECONDS`, `WORKER_MEMORY_MB`, `MAX_STEPS`,
`MAX_RESULTS`, `MAX_STATEMENTS_PER_KB`, and `MAX_KB_SOURCE_BYTES`.

## Benchmarks

Run the NatDist vs ParticleDist benchmark:

```bash
python pettachainer/benchmarks/particle_vs_nat.py --sizes 100,500,1000 --particle-budgets 128,256,512 --repeats 2
```

Run the simple forward vs backward chaining benchmark:

```bash
.venv/bin/python pettachainer/benchmarks/forward_vs_backward.py --depths 10,25,50 --noise-branching 8 --repeats 3
```

Run the backward materialization benchmark:

```bash
.venv/bin/python pettachainer/benchmarks/backward_materialize.py --depths 5,10 --queries 200 --repeats 3
```

Run the bounded priority queue benchmark:

```bash
.venv/bin/python pettachainer/benchmarks/bounded_queue.py --fanouts 2000,8000 --steps 100 --repeats 3
```

Add `--compare-pruning` to compare pruning enabled and disabled within the same checkout.

Optional JSON export:

```bash
python pettachainer/benchmarks/particle_vs_nat.py --json-out /tmp/particle_bench.json
```

## Profiling MeTTa Runs

Profile a `.metta` file through the underlying SWI-Prolog invocation that `petta` uses:

```bash
./profile_petta.sh tests/testmining.metta
./profile_petta.sh --mode time tests/testmining.metta
./profile_petta.sh --mode perf benchmarks/demo_benchgen_forward_backward_compare.metta
```

Relative paths are resolved from `pettachainer/metta` by default.

## Python API: Language Spec String

```python
from pettachainer import get_language_spec

llm_spec = get_language_spec(llm_focused=True)
full_spec = get_language_spec(llm_focused=False)
```

## Python API: Shared PLN Validator

```python
from pettachainer import PeTTaChainer, check_query, check_stmt

handler = PeTTaChainer()

stmt_eval = handler.evaluate_statement("(: s1 (Dog fido) (STV 1.0 1.0))")
check_stmt(stmt_eval)

query_eval = handler.evaluate_query("(: $prf (Dog fido) $tv)")
check_query(query_eval)
```

## Python API: Forward Chaining

```python
from pettachainer import PeTTaChainer

handler = PeTTaChainer()
handler.add_atom("(: edge_ab (Edge A B) (STV 1.0 1.0))")
handler.add_atom("(: edge_bc (Edge B C) (STV 1.0 1.0))")
handler.add_atom("(: edge_to_path (Implication (Premises (Edge $x $y)) (Conclusions (Path $x $y))) (STV 1.0 1.0))")
handler.add_atom("(: path_step (Implication (Premises (Path $x $y) (Edge $y $z)) (Conclusions (Path $x $z))) (STV 1.0 1.0))")

handler.forward_chain(steps=50)
result = handler.query("(: $prf (Path A C) $tv)", timeout_sec=0)

handler.forward_chain(steps=1, term="(Edge A B)")
```
