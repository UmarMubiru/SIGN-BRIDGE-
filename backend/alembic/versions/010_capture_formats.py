"""Replace repetition protocol with three required capture formats.

Revision ID: 010
Revises: 009
"""
from alembic import op
import sqlalchemy as sa

revision = "010"
down_revision = "009"
branch_labels = None
depends_on = None


def upgrade():
    inspector = sa.inspect(op.get_bind())
    recording_columns = {column["name"] for column in inspector.get_columns("recordings")}
    if "capture_format" not in recording_columns:
        op.add_column("recordings", sa.Column("capture_format", sa.String(32), nullable=True))
    existing_indexes = {index["name"] for index in sa.inspect(op.get_bind()).get_indexes("recordings")}
    if "ix_recordings_capture_format" not in existing_indexes:
        op.create_index("ix_recordings_capture_format", "recordings", ["capture_format"])

    # Remove any old uniqueness rule based on repetition, then enforce one row
    # per format. NULL formats remain valid for historical recordings.
    unique_constraints = sa.inspect(op.get_bind()).get_unique_constraints("recordings")
    with op.batch_alter_table("recordings") as batch:
        for constraint in unique_constraints:
            if "repetition_no" in (constraint.get("column_names") or []) and constraint.get("name"):
                batch.drop_constraint(constraint["name"], type_="unique")
        if not any(set(c.get("column_names") or []) == {"session_id", "sign_id", "capture_format"} for c in unique_constraints):
            batch.create_unique_constraint(
                "uq_session_sign_capture_format", ["session_id", "sign_id", "capture_format"]
            )

    if "signs" in sa.inspect(op.get_bind()).get_table_names():
        op.execute("UPDATE signs SET target_repetitions = 3")


def downgrade():
    with op.batch_alter_table("recordings") as batch:
        batch.drop_constraint("uq_session_sign_capture_format", type_="unique")
        batch.create_unique_constraint("uq_session_sign_repetition", ["session_id", "sign_id", "repetition_no"])
        batch.drop_column("capture_format")
    op.drop_index("ix_recordings_capture_format", table_name="recordings")
    op.execute("UPDATE signs SET target_repetitions = 10")

