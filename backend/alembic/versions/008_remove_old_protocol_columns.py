"""Remove old protocol columns from recordings table

Revision ID: 008
Revises: 007
Create Date: 2026-09-27

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '008'
down_revision = '007'
branch_labels = None
depends_on = None


def upgrade():
    # Remove old protocol columns that are no longer used (if they exist)
    inspector = sa.inspect(op.get_bind())
    recording_columns = {column["name"] for column in inspector.get_columns("recordings")}
    
    if 'preset' in recording_columns:
        op.drop_column('recordings', 'preset')
    
    if 'status' in recording_columns:
        op.drop_column('recordings', 'status')
    
    if 'camera_position' in recording_columns:
        op.drop_column('recordings', 'camera_position')
    
    if 'distance' in recording_columns:
        op.drop_column('recordings', 'distance')
    
    # Ensure new columns exist (they should from migration 007)
    # But add them if they don't exist
    if 'recording_status' not in recording_columns:
        op.add_column('recordings', sa.Column('recording_status', sa.String(50), nullable=False, server_default='pending_review'))
    
    if 'validation_status' not in recording_columns:
        op.add_column('recordings', sa.Column('validation_status', sa.String(50), nullable=False, server_default='pending'))


def downgrade():
    # Add back old columns for rollback
    op.add_column('recordings', sa.Column('preset', sa.String(50), nullable=True))
    op.add_column('recordings', sa.Column('status', sa.String(50), nullable=True))
    op.add_column('recordings', sa.Column('camera_position', sa.String(50), nullable=True))
    op.add_column('recordings', sa.Column('distance', sa.String(50), nullable=True))
