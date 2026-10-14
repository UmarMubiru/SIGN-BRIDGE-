"""Store verified MIME type and canonical object path for cloud recordings.

Revision ID: 014
Revises: 013
"""
from alembic import op
import sqlalchemy as sa

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recordings")}
    with op.batch_alter_table("recordings") as batch:
        if "mime_type" not in columns:
            batch.add_column(sa.Column("mime_type", sa.String(100), nullable=True))
        if "storage_path" not in columns:
            batch.add_column(sa.Column("storage_path", sa.String(500), nullable=True))
    if "cloud_object_key" in columns and "storage_path" not in columns:
        op.execute("UPDATE recordings SET storage_path = cloud_object_key WHERE cloud_object_key IS NOT NULL")


def downgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recordings")}
    with op.batch_alter_table("recordings") as batch:
        if "storage_path" in columns:
            batch.drop_column("storage_path")
        if "mime_type" in columns:
            batch.drop_column("mime_type")
