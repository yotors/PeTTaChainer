import threading
import uuid

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .config import Settings
from .models import KnowledgeBase, KnowledgeBaseEvent, Statement
from .policy import ParsedStatement
from .worker import run_worker


class NotFoundError(LookupError):
    pass


class LimitExceededError(ValueError):
    pass


class ConflictError(ValueError):
    pass


_worker_limit: threading.BoundedSemaphore | None = None
_worker_limit_size: int | None = None
_worker_limit_lock = threading.Lock()


def _semaphore(size: int) -> threading.BoundedSemaphore:
    global _worker_limit, _worker_limit_size
    with _worker_limit_lock:
        if _worker_limit is None or _worker_limit_size != size:
            _worker_limit = threading.BoundedSemaphore(size)
            _worker_limit_size = size
        return _worker_limit


def owned_kb(db: Session, kb_id: uuid.UUID, owner_id: str, *, lock: bool = False) -> KnowledgeBase:
    query = select(KnowledgeBase).where(
        KnowledgeBase.id == kb_id,
        KnowledgeBase.owner_id == owner_id,
    )
    if lock:
        query = query.with_for_update()
    knowledge_base = db.scalar(query)
    if knowledge_base is None:
        raise NotFoundError("knowledge base not found")
    return knowledge_base


def add_statement(
    db: Session,
    kb_id: uuid.UUID,
    owner_id: str,
    parsed: ParsedStatement,
    mine_patterns: bool,
    idempotency_key: str,
    settings: Settings,
) -> Statement:
    knowledge_base = owned_kb(db, kb_id, owner_id, lock=True)
    existing = db.scalar(
        select(Statement).where(
            Statement.knowledge_base_id == kb_id,
            Statement.idempotency_key == idempotency_key,
        )
    )
    if existing is not None:
        if existing.source != parsed.source or existing.mine_patterns != mine_patterns:
            raise ConflictError("idempotency key was already used for a different statement")
        return existing

    count, total_bytes = db.execute(
        select(func.count(Statement.id), func.coalesce(func.sum(func.length(Statement.source)), 0)).where(
            Statement.knowledge_base_id == kb_id
        )
    ).one()
    source_bytes = len(parsed.source.encode("utf-8"))
    if count >= settings.max_statements_per_kb:
        raise LimitExceededError("knowledge base statement limit reached")
    if total_bytes + source_bytes > settings.max_kb_source_bytes:
        raise LimitExceededError("knowledge base source-size limit reached")

    knowledge_base.revision += 1
    statement = Statement(
        knowledge_base_id=kb_id,
        kind=parsed.kind,
        source=parsed.source,
        mine_patterns=mine_patterns,
        created_revision=knowledge_base.revision,
        idempotency_key=idempotency_key,
    )
    db.add(statement)
    db.flush()
    db.add(
        KnowledgeBaseEvent(
            knowledge_base_id=kb_id,
            revision=knowledge_base.revision,
            operation="add",
            statement_id=statement.id,
            idempotency_key=idempotency_key,
        )
    )
    db.commit()
    db.refresh(statement)
    return statement


def statement_payloads(db: Session, kb_id: uuid.UUID, owner_id: str):
    knowledge_base = owned_kb(db, kb_id, owner_id)
    statements = db.scalars(
        select(Statement)
        .where(Statement.knowledge_base_id == kb_id)
        .order_by(Statement.created_revision)
    ).all()
    return knowledge_base, [
        {"source": statement.source, "mine_patterns": statement.mine_patterns}
        for statement in statements
    ]


def execute(job: dict, settings: Settings) -> dict:
    with _semaphore(settings.max_concurrent_workers):
        return run_worker(
            job,
            timeout_seconds=settings.worker_timeout_seconds,
            memory_mb=settings.worker_memory_mb,
            max_files=settings.worker_max_files,
        )
