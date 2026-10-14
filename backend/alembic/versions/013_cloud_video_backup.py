"""Track optional S3-compatible recording backups.

Revision ID: 013
Revises: 012
"""
from alembic import op
import sqlalchemy as sa

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recordings")}
    with op.batch_alter_table("recordings") as batch:
        if "cloud_storage_status" not in columns:
            batch.add_column(sa.Column("cloud_storage_status", sa.String(20), nullable=False, server_default="local_only"))
        if "cloud_storage_error" not in columns:
            batch.add_column(sa.Column("cloud_storage_error", sa.Text(), nullable=True))
        if "cloud_object_key" not in columns:
            batch.add_column(sa.Column("cloud_object_key", sa.String(500), nullable=True))
    with op.batch_alter_table("recordings") as batch:
        batch.alter_column("cloud_storage_status", server_default=None)


def downgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recordings")}
    with op.batch_alter_table("recordings") as batch:
        for name in ("cloud_object_key", "cloud_storage_error", "cloud_storage_status"):
            if name in columns:
                batch.drop_column(name)
