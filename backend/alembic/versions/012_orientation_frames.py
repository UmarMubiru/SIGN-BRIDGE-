"""Store automatically sampled frames and pose/landmark annotations.

Revision ID: 012
Revises: 011
"""
from alembic import op
import sqlalchemy as sa

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    columns = {column["name"] for column in sa.inspect(bind).get_columns("recordings")}
    with op.batch_alter_table("recordings") as batch:
        if "orientation_status" not in columns:
            batch.add_column(sa.Column("orientation_status", sa.String(20), nullable=False, server_default="pending"))
        if "orientation_error" not in columns:
            batch.add_column(sa.Column("orientation_error", sa.Text(), nullable=True))
        if "processed_frame_count" not in columns:
            batch.add_column(sa.Column("processed_frame_count", sa.Integer(), nullable=False, server_default="0"))
    with op.batch_alter_table("recordings") as batch:
        batch.alter_column("orientation_status", server_default=None)
        batch.alter_column("processed_frame_count", server_default=None)

    if "orientation_frames" not in sa.inspect(bind).get_table_names():
        op.create_table(
            "orientation_frames",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("recording_id", sa.String(36), sa.ForeignKey("recordings.id", ondelete="CASCADE"), nullable=False),
            sa.Column("frame_index", sa.Integer(), nullable=False),
            sa.Column("timestamp_ms", sa.Integer(), nullable=False),
            sa.Column("yaw_degrees", sa.Float(), nullable=True),
            sa.Column("pitch_degrees", sa.Float(), nullable=True),
            sa.Column("orientation_label", sa.String(32), nullable=False),
            sa.Column("face_landmarks", sa.JSON(), nullable=True),
            sa.Column("hand_landmarks", sa.JSON(), nullable=False),
            sa.Column("image_url", sa.String(500), nullable=False),
        )
        op.create_index("ix_orientation_frames_recording_id", "orientation_frames", ["recording_id"])


def downgrade():
    if "orientation_frames" in sa.inspect(op.get_bind()).get_table_names():
        op.drop_index("ix_orientation_frames_recording_id", table_name="orientation_frames")
        op.drop_table("orientation_frames")
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recordings")}
    with op.batch_alter_table("recordings") as batch:
        for name in ("processed_frame_count", "orientation_error", "orientation_status"):
            if name in columns:
                batch.drop_column(name)
