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


def add_statements(
    db: Session,
    kb_id: uuid.UUID,
    owner_id: str,
    items: list[tuple[ParsedStatement, bool, str]],
    settings: Settings,
) -> tuple[list[Statement], int]:
    knowledge_base = owned_kb(db, kb_id, owner_id, lock=True)
    keys = [idempotency_key for _, _, idempotency_key in items]
    if len(keys) != len(set(keys)):
        raise ConflictError("idempotency keys must be unique within a bulk request")
    existing_by_key = {
        statement.idempotency_key: statement
        for statement in db.scalars(
            select(Statement).where(
                Statement.knowledge_base_id == kb_id,
                Statement.idempotency_key.in_(keys),
            )
        ).all()
    }
    new_items: list[tuple[ParsedStatement, bool, str]] = []
    ordered: list[Statement | None] = []
    for parsed, mine_patterns, idempotency_key in items:
        existing = existing_by_key.get(idempotency_key)
        if existing is not None:
            if existing.source != parsed.source or existing.mine_patterns != mine_patterns:
                raise ConflictError("idempotency key was already used for a different statement")
            ordered.append(existing)
        else:
            ordered.append(None)
            new_items.append((parsed, mine_patterns, idempotency_key))

    count, total_bytes = db.execute(
        select(func.count(Statement.id), func.coalesce(func.sum(func.length(Statement.source)), 0)).where(
            Statement.knowledge_base_id == kb_id
        )
    ).one()
    source_bytes = sum(len(parsed.source.encode("utf-8")) for parsed, _, _ in new_items)
    if count + len(new_items) > settings.max_statements_per_kb:
        raise LimitExceededError("knowledge base statement limit reached")
    if total_bytes + source_bytes > settings.max_kb_source_bytes:
        raise LimitExceededError("knowledge base source-size limit reached")

    created_by_key: dict[str, Statement] = {}
    for parsed, mine_patterns, idempotency_key in new_items:
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
        created_by_key[idempotency_key] = statement
    db.commit()
    result = [
        statement or created_by_key[idempotency_key]
        for statement, (_, _, idempotency_key) in zip(ordered, items)
    ]
    return result, knowledge_base.revision


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
