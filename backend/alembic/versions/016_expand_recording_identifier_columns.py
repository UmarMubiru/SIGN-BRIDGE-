"""Expand recording identifiers to match the API models.

Revision ID: 016
Revises: 015
"""
from alembic import op
import sqlalchemy as sa


revision = "016"
down_revision = "015"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("recordings") as batch:
        batch.alter_column(
            "public_id",
            existing_type=sa.String(length=20),
            type_=sa.String(length=50),
            existing_nullable=False,
        )
        batch.alter_column(
            "client_id",
            existing_type=sa.String(length=50),
            type_=sa.String(length=100),
            existing_nullable=False,
        )


def downgrade():
    # Refuse to truncate identifiers created after this migration.
    bind = op.get_bind()
    too_long = bind.execute(
        sa.text(
            "SELECT 1 FROM recordings "
            "WHERE length(public_id) > 20 OR length(client_id) > 50 LIMIT 1"
        )
    ).first()
    if too_long:
        raise RuntimeError("Cannot shrink recording identifier columns: values would be truncated")

    with op.batch_alter_table("recordings") as batch:
        batch.alter_column(
            "public_id",
            existing_type=sa.String(length=50),
            type_=sa.String(length=20),
            existing_nullable=False,
        )
        batch.alter_column(
            "client_id",
            existing_type=sa.String(length=100),
            type_=sa.String(length=50),
            existing_nullable=False,
        )
