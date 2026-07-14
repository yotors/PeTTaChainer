from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from pettachainer.server.app import create_app
from pettachainer.server.config import Settings
from pettachainer.server.database import Base, get_db


def make_client(monkeypatch):
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    settings = Settings(
        environment="test",
        database_url="sqlite+pysqlite://",
        api_keys=[],
        allowed_hosts=["testserver"],
        max_statement_chars=10_000,
        max_query_chars=10_000,
    )
    app = create_app(settings)

    def session_override():
        with Session(engine, expire_on_commit=False) as session:
            yield session

    def fake_execute(job, _settings):
        if job["operation"] == "validate":
            return {"evaluated": job["source"]}
        if job["operation"] == "backward":
            return {"results": ["(: proof (Animal fido) (STV 1.0 1.0))"]}
        return {"forward_result": ["true"], "query_results": ["(: proof (Animal fido) (STV 1.0 1.0))"]}

    app.dependency_overrides[get_db] = session_override
    monkeypatch.setattr("pettachainer.server.app.execute", fake_execute)
    return TestClient(app)


def test_kb_statement_and_reasoning_flow(monkeypatch):
    with make_client(monkeypatch) as client:
        created = client.post("/v1/knowledge-bases", json={"name": "animals"})
        assert created.status_code == 201
        kb_id = created.json()["id"]

        added = client.post(
            f"/v1/knowledge-bases/{kb_id}/statements",
            headers={"Idempotency-Key": "add-dog"},
            json={"source": "(: dog (Dog fido) (STV 1.0 1.0))"},
        )
        assert added.status_code == 201
        assert added.json()["kind"] == "fact"
        assert added.json()["created_revision"] == 1

        retried = client.post(
            f"/v1/knowledge-bases/{kb_id}/statements",
            headers={"Idempotency-Key": "add-dog"},
            json={"source": "(: dog (Dog fido) (STV 1.0 1.0))"},
        )
        assert retried.status_code == 201
        assert retried.json()["id"] == added.json()["id"]

        conflicting_retry = client.post(
            f"/v1/knowledge-bases/{kb_id}/statements",
            headers={"Idempotency-Key": "add-dog"},
            json={"source": "(: cat (Cat fido) (STV 1.0 1.0))"},
        )
        assert conflicting_retry.status_code == 409
        assert conflicting_retry.json()["error"]["code"] == "idempotency_conflict"

        backward = client.post(
            f"/v1/knowledge-bases/{kb_id}/reason/backward",
            json={"query": "(: $proof (Animal fido) $tv)", "steps": 20},
        )
        assert backward.status_code == 200
        assert backward.json()["revision"] == 1
        assert backward.json()["results"]

        forward = client.post(
            f"/v1/knowledge-bases/{kb_id}/reason/forward",
            json={"steps": 20, "query": "(: $proof (Animal fido) $tv)"},
        )
        assert forward.status_code == 200
        assert forward.json()["forward_result"] == ["true"]


def test_policy_errors_are_structured(monkeypatch):
    with make_client(monkeypatch) as client:
        response = client.post(
            "/v1/validate",
            json={
                "kind": "statement",
                "source": '(: bad (eval (py-eval "danger")) (STV 1.0 1.0))',
            },
        )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "policy_violation"
    assert response.headers["X-Request-ID"]


def test_unknown_kb_does_not_leak_data(monkeypatch):
    with make_client(monkeypatch) as client:
        response = client.get("/v1/knowledge-bases/00000000-0000-0000-0000-000000000001")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"
