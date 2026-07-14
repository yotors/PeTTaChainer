import uuid
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session
from starlette.middleware.base import BaseHTTPMiddleware

from .auth import Principal, authenticate
from .config import Settings, get_settings
from .database import get_db
from .models import KnowledgeBase, Statement
from .policy import PolicyViolation, validate_query_source, validate_seed_term, validate_statement_source
from .schemas import (
    AddStatement,
    BackwardReasonRequest,
    BackwardReasonResponse,
    BulkAddStatements,
    CreateKnowledgeBase,
    ForwardReasonRequest,
    ForwardReasonResponse,
    KnowledgeBaseList,
    KnowledgeBaseResponse,
    StatementList,
    StatementResponse,
    ValidateRequest,
    ValidateResponse,
)
from .service import (
    ConflictError,
    LimitExceededError,
    NotFoundError,
    add_statements,
    execute,
    owned_kb,
    statement_payloads,
)
from .worker import WorkerError, WorkerTimeout


def _error(request: Request, status_code: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "error": {
                "code": code,
                "message": message,
                "request_id": getattr(request.state, "request_id", "unknown"),
            }
        },
        headers={"X-Request-ID": getattr(request.state, "request_id", "unknown")},
    )


class RequestBoundaryMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, max_bytes: int):
        super().__init__(app)
        self.max_bytes = max_bytes

    async def dispatch(self, request: Request, call_next):
        request.state.request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))[:128]
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > self.max_bytes:
                    return _error(request, 413, "request_too_large", "request body is too large")
            except ValueError:
                return _error(request, 400, "invalid_content_length", "invalid Content-Length header")
        response = await call_next(request)
        response.headers["X-Request-ID"] = request.state.request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Cache-Control"] = "no-store"
        return response


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        settings.validate_for_server()
        yield

    app = FastAPI(
        title="PeTTaChainer API",
        version="0.1.0",
        docs_url=None if settings.environment == "production" else "/docs",
        redoc_url=None,
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.dependency_overrides[get_settings] = lambda: settings
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.allowed_hosts)
    app.add_middleware(RequestBoundaryMiddleware, max_bytes=settings.max_request_bytes)

    @app.exception_handler(RequestValidationError)
    async def request_validation_error(request: Request, exc: RequestValidationError):
        message = "; ".join(error["msg"] for error in exc.errors()[:5])
        return _error(request, 422, "request_validation_failed", message)

    @app.exception_handler(HTTPException)
    async def http_error(request: Request, exc: HTTPException):
        return _error(request, exc.status_code, "http_error", str(exc.detail))

    @app.exception_handler(PolicyViolation)
    async def policy_error(request: Request, exc: PolicyViolation):
        return _error(request, 422, "policy_violation", str(exc))

    @app.exception_handler(NotFoundError)
    async def not_found_error(request: Request, exc: NotFoundError):
        return _error(request, 404, "not_found", str(exc))

    @app.exception_handler(LimitExceededError)
    async def limit_error(request: Request, exc: LimitExceededError):
        return _error(request, 409, "limit_exceeded", str(exc))

    @app.exception_handler(ConflictError)
    async def conflict_error(request: Request, exc: ConflictError):
        return _error(request, 409, "idempotency_conflict", str(exc))

    @app.exception_handler(WorkerTimeout)
    async def worker_timeout(request: Request, exc: WorkerTimeout):
        return _error(request, 504, "reasoning_timeout", str(exc))

    @app.exception_handler(WorkerError)
    async def worker_error(request: Request, exc: WorkerError):
        return _error(request, 422, "reasoning_failed", str(exc))

    @app.exception_handler(IntegrityError)
    async def integrity_error(request: Request, _exc: IntegrityError):
        return _error(request, 409, "conflict", "the operation conflicts with existing data")

    @app.exception_handler(SQLAlchemyError)
    async def database_error(request: Request, _exc: SQLAlchemyError):
        return _error(request, 503, "database_unavailable", "database operation failed")

    @app.get("/healthz", include_in_schema=False)
    def healthz():
        return {"status": "ok"}

    @app.get("/readyz", include_in_schema=False)
    def readyz(db: Session = Depends(get_db)):
        db.execute(text("SELECT 1"))
        return {"status": "ready"}

    @app.post("/v1/knowledge-bases", response_model=KnowledgeBaseResponse, status_code=201)
    def create_knowledge_base(
        body: CreateKnowledgeBase,
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        knowledge_base = KnowledgeBase(
            owner_id=principal.owner_id,
            name=body.name.strip(),
            logic_config=body.logic_config,
        )
        db.add(knowledge_base)
        db.commit()
        db.refresh(knowledge_base)
        return knowledge_base

    @app.get("/v1/knowledge-bases", response_model=KnowledgeBaseList)
    def list_knowledge_bases(
        limit: int = Query(default=100, ge=1, le=500),
        offset: int = Query(default=0, ge=0),
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        items = db.scalars(
            select(KnowledgeBase)
            .where(KnowledgeBase.owner_id == principal.owner_id)
            .order_by(KnowledgeBase.created_at, KnowledgeBase.id)
            .offset(offset)
            .limit(limit)
        ).all()
        return {"items": items}

    @app.get("/v1/knowledge-bases/{kb_id}", response_model=KnowledgeBaseResponse)
    def get_knowledge_base(
        kb_id: uuid.UUID,
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        return owned_kb(db, kb_id, principal.owner_id)

    @app.delete("/v1/knowledge-bases/{kb_id}", status_code=204)
    def delete_knowledge_base(
        kb_id: uuid.UUID,
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        knowledge_base = owned_kb(db, kb_id, principal.owner_id, lock=True)
        db.delete(knowledge_base)
        db.commit()

    @app.post(
        "/v1/knowledge-bases/{kb_id}/statements",
        response_model=StatementResponse,
        status_code=201,
    )
    def create_statement(
        kb_id: uuid.UUID,
        body: AddStatement,
        idempotency_key: str = Header(min_length=1, max_length=200, alias="Idempotency-Key"),
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        parsed = validate_statement_source(body.source, settings.max_statement_chars)
        knowledge_base = owned_kb(db, kb_id, principal.owner_id)
        execute(
            {
                "operation": "validate",
                "kind": "statement",
                "source": parsed.source,
                "logic_config": knowledge_base.logic_config,
            },
            settings,
        )
        statements, _revision = add_statements(
            db,
            kb_id,
            principal.owner_id,
            [(parsed, body.mine_patterns, idempotency_key)],
            settings,
        )
        return statements[0]

    @app.post(
        "/v1/knowledge-bases/{kb_id}/statements/bulk",
        response_model=StatementList,
        status_code=201,
    )
    def create_statements_bulk(
        kb_id: uuid.UUID,
        body: BulkAddStatements,
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        if len(body.statements) > settings.max_statements_per_kb:
            raise LimitExceededError("bulk request exceeds the knowledge base statement limit")
        parsed_items = [
            (
                validate_statement_source(item.source, settings.max_statement_chars),
                item.mine_patterns,
                item.idempotency_key,
            )
            for item in body.statements
        ]
        knowledge_base = owned_kb(db, kb_id, principal.owner_id)
        execute(
            {
                "operation": "validate_statements",
                "sources": [parsed.source for parsed, _, _ in parsed_items],
                "logic_config": knowledge_base.logic_config,
            },
            settings,
        )
        statements, revision = add_statements(
            db,
            kb_id,
            principal.owner_id,
            parsed_items,
            settings,
        )
        return {"items": statements, "revision": revision}

    @app.get("/v1/knowledge-bases/{kb_id}/statements", response_model=StatementList)
    def list_statements(
        kb_id: uuid.UUID,
        limit: int = Query(default=100, ge=1, le=500),
        offset: int = Query(default=0, ge=0),
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        knowledge_base = owned_kb(db, kb_id, principal.owner_id)
        items = db.scalars(
            select(Statement)
            .where(Statement.knowledge_base_id == kb_id)
            .order_by(Statement.created_revision)
            .offset(offset)
            .limit(limit)
        ).all()
        return {"items": items, "revision": knowledge_base.revision}

    @app.post("/v1/validate", response_model=ValidateResponse)
    def validate(
        body: ValidateRequest,
        _principal: Principal = Depends(authenticate),
    ):
        source = (
            validate_statement_source(body.source, settings.max_statement_chars).source
            if body.kind == "statement"
            else validate_query_source(body.source, settings.max_query_chars)
        )
        result = execute(
            {"operation": "validate", "kind": body.kind, "source": source, "logic_config": "pln"},
            settings,
        )
        return {"valid": True, "kind": body.kind, "evaluated": result["evaluated"]}

    @app.post(
        "/v1/knowledge-bases/{kb_id}/reason/backward",
        response_model=BackwardReasonResponse,
    )
    def reason_backward(
        kb_id: uuid.UUID,
        body: BackwardReasonRequest,
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        if body.steps > settings.max_steps:
            raise LimitExceededError("reasoning step limit exceeded")
        query = validate_query_source(body.query, settings.max_query_chars)
        knowledge_base, statements = statement_payloads(db, kb_id, principal.owner_id)
        result = execute(
            {
                "operation": "backward",
                "logic_config": knowledge_base.logic_config,
                "statements": statements,
                "query": query,
                "steps": body.steps,
                "max_derivations": settings.max_derivations,
            },
            settings,
        )
        maximum = min(body.max_results or settings.max_results, settings.max_results)
        results = result["results"]
        return {
            "knowledge_base_id": kb_id,
            "revision": knowledge_base.revision,
            "results": results[:maximum],
            "truncated": len(results) > maximum,
        }

    @app.post(
        "/v1/knowledge-bases/{kb_id}/reason/forward",
        response_model=ForwardReasonResponse,
    )
    def reason_forward(
        kb_id: uuid.UUID,
        body: ForwardReasonRequest,
        principal: Principal = Depends(authenticate),
        db: Session = Depends(get_db),
    ):
        if body.steps > settings.max_steps or body.query_steps > settings.max_steps:
            raise LimitExceededError("reasoning step limit exceeded")
        seeds = None
        if body.seed_terms is not None:
            if not body.seed_terms:
                raise PolicyViolation("seed_terms cannot be empty")
            seeds = [validate_seed_term(term, settings.max_query_chars) for term in body.seed_terms]
        query = validate_query_source(body.query, settings.max_query_chars) if body.query else None
        knowledge_base, statements = statement_payloads(db, kb_id, principal.owner_id)
        result = execute(
            {
                "operation": "forward",
                "logic_config": knowledge_base.logic_config,
                "statements": statements,
                "steps": body.steps,
                "seed_terms": seeds,
                "query": query,
                "query_steps": body.query_steps,
                "max_derivations": settings.max_derivations,
            },
            settings,
        )
        maximum = min(body.max_results or settings.max_results, settings.max_results)
        query_results = result["query_results"]
        truncated = query_results is not None and len(query_results) > maximum
        return {
            "knowledge_base_id": kb_id,
            "revision": knowledge_base.revision,
            "forward_result": result["forward_result"],
            "query_results": query_results[:maximum] if query_results is not None else None,
            "truncated": truncated,
        }

    return app


app = create_app()
