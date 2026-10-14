"""Create activity log for recent dashboard events.

Revision ID: 009
Revises: 008
Create Date: 2026-09-27
"""
from alembic import op
import sqlalchemy as sa


revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade():
    inspector = sa.inspect(op.get_bind())
    if "activity_logs" not in inspector.get_table_names():
        op.create_table(
            "activity_logs",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("actor_id", sa.String(length=36), nullable=True),
            sa.Column("event_type", sa.String(length=50), nullable=False),
            sa.Column("message", sa.String(length=255), nullable=False),
            sa.Column("details", sa.Text(), nullable=True),
            sa.Column("recording_id", sa.String(length=36), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["actor_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
        )

    existing_indexes = {index["name"] for index in sa.inspect(op.get_bind()).get_indexes("activity_logs")}
    for name, column in (
        ("ix_activity_logs_event_type", "event_type"),
        ("ix_activity_logs_recording_id", "recording_id"),
        ("ix_activity_logs_created_at", "created_at"),
    ):
        if name not in existing_indexes:
            op.create_index(name, "activity_logs", [column])


def downgrade():
    op.drop_index("ix_activity_logs_created_at", table_name="activity_logs")
    op.drop_index("ix_activity_logs_recording_id", table_name="activity_logs")
    op.drop_index("ix_activity_logs_event_type", table_name="activity_logs")
    op.drop_table("activity_logs")
