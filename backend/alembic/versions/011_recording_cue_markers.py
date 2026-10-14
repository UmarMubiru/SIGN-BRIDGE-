"""Persist guided cue timestamps for continuous capture videos.

Revision ID: 011
Revises: 010
"""
from alembic import op
import sqlalchemy as sa

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


def upgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recordings")}
    if "cue_markers" not in columns:
        op.add_column("recordings", sa.Column("cue_markers", sa.JSON(), nullable=False, server_default="[]"))
        with op.batch_alter_table("recordings") as batch:
            batch.alter_column("cue_markers", server_default=None)


def downgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recordings")}
    if "cue_markers" in columns:
        op.drop_column("recordings", "cue_markers")
