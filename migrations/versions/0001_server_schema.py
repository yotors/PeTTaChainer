"""Create the persistent server schema."""

from alembic import op
import sqlalchemy as sa


revision = "0001_server_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "knowledge_bases",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("logic_config", sa.String(length=32), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_knowledge_bases_owner_id", "knowledge_bases", ["owner_id"])
    op.create_index(
        "ix_knowledge_bases_owner_created", "knowledge_bases", ["owner_id", "created_at"]
    )
    op.create_table(
        "statements",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("knowledge_base_id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(length=24), nullable=False),
        sa.Column("source", sa.Text(), nullable=False),
        sa.Column("mine_patterns", sa.Boolean(), nullable=False),
        sa.Column("created_revision", sa.Integer(), nullable=False),
        sa.Column("idempotency_key", sa.String(length=200), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["knowledge_base_id"], ["knowledge_bases.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "knowledge_base_id", "idempotency_key", name="uq_statement_kb_idempotency"
        ),
    )
    op.create_index("ix_statements_knowledge_base_id", "statements", ["knowledge_base_id"])
    op.create_index(
        "ix_statements_kb_revision", "statements", ["knowledge_base_id", "created_revision"]
    )
    op.create_table(
        "knowledge_base_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("knowledge_base_id", sa.Uuid(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("operation", sa.String(length=16), nullable=False),
        sa.Column("statement_id", sa.Uuid(), nullable=False),
        sa.Column("idempotency_key", sa.String(length=200), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["knowledge_base_id"], ["knowledge_bases.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "knowledge_base_id", "idempotency_key", name="uq_event_kb_idempotency"
        ),
        sa.UniqueConstraint("knowledge_base_id", "revision", name="uq_event_kb_revision"),
    )
    op.create_index(
        "ix_knowledge_base_events_knowledge_base_id",
        "knowledge_base_events",
        ["knowledge_base_id"],
    )


def downgrade() -> None:
    op.drop_table("knowledge_base_events")
    op.drop_table("statements")
    op.drop_table("knowledge_bases")
