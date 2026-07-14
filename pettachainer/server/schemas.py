import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ApiModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CreateKnowledgeBase(ApiModel):
    name: str = Field(min_length=1, max_length=200)
    logic_config: Literal["pln"] = "pln"


class KnowledgeBaseResponse(ApiModel):
    id: uuid.UUID
    name: str
    logic_config: str
    revision: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True, extra="forbid")


class KnowledgeBaseList(ApiModel):
    items: list[KnowledgeBaseResponse]


class AddStatement(ApiModel):
    source: str = Field(min_length=1, max_length=1_000_000)
    mine_patterns: bool = False


class BulkStatementItem(AddStatement):
    idempotency_key: str = Field(min_length=1, max_length=200)


class BulkAddStatements(ApiModel):
    statements: list[BulkStatementItem] = Field(min_length=1, max_length=10_000)


class StatementResponse(ApiModel):
    id: uuid.UUID
    knowledge_base_id: uuid.UUID
    kind: str
    source: str
    mine_patterns: bool
    created_revision: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True, extra="forbid")


class StatementList(ApiModel):
    items: list[StatementResponse]
    revision: int


class ValidateRequest(ApiModel):
    kind: Literal["statement", "query"]
    source: str = Field(min_length=1, max_length=1_000_000)


class ValidateResponse(ApiModel):
    valid: bool
    kind: str
    evaluated: str


class BackwardReasonRequest(ApiModel):
    query: str = Field(min_length=1, max_length=1_000_000)
    steps: int = Field(default=100, ge=1)
    max_results: int | None = Field(default=None, ge=1)


class BackwardReasonResponse(ApiModel):
    knowledge_base_id: uuid.UUID
    revision: int
    results: list[str]
    truncated: bool


class ForwardReasonRequest(ApiModel):
    steps: int = Field(default=100, ge=1)
    seed_terms: list[str] | None = Field(default=None, max_length=100)
    query: str | None = Field(default=None, max_length=1_000_000)
    query_steps: int = Field(default=100, ge=1)
    max_results: int | None = Field(default=None, ge=1)


class ForwardReasonResponse(ApiModel):
    knowledge_base_id: uuid.UUID
    revision: int
    forward_result: list[str]
    query_results: list[str] | None
    truncated: bool


class ErrorDetail(ApiModel):
    code: str
    message: str
    request_id: str


class ErrorResponse(ApiModel):
    error: ErrorDetail
