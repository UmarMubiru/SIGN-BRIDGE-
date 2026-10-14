"""refactor_recording_protocol

Revision ID: 007
Revises: 006
Create Date: 2025-01-15

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '007'
down_revision = '006'
branch_labels = None
depends_on = None


def upgrade():
    # Add lighting and background to sessions
    op.add_column('collection_sessions', sa.Column('lighting_condition', sa.String(50), nullable=False, server_default='Daylight'))
    op.add_column('collection_sessions', sa.Column('background', sa.String(50), nullable=False, server_default='Plain Wall — Light'))
    
    # Rename repetition to repetition_no in recordings
    op.execute("ALTER TABLE recordings RENAME COLUMN repetition TO repetition_no")
    
    # Add camera_angle column
    op.add_column('recordings', sa.Column('camera_angle', sa.String(50), nullable=False, server_default='Front (0°)'))
    
    # Add lighting_condition column
    op.add_column('recordings', sa.Column('lighting_condition', sa.String(50), nullable=False, server_default='Daylight'))
    
    # Add background column
    op.add_column('recordings', sa.Column('background', sa.String(50), nullable=False, server_default='Plain Wall — Light'))
    
    # Add file_name column
    op.add_column('recordings', sa.Column('file_name', sa.String(255), nullable=False))
    
    # Add file_url column
    op.add_column('recordings', sa.Column('file_url', sa.String(500), nullable=True))
    
    # Add file_size column
    op.add_column('recordings', sa.Column('file_size', sa.Integer, nullable=True))
    
    # Add duration column
    op.add_column('recordings', sa.Column('duration', sa.Integer, nullable=True))
    
    # Add resolution column
    op.add_column('recordings', sa.Column('resolution', sa.String(20), nullable=True))
    
    # Add fps column
    op.add_column('recordings', sa.Column('fps', sa.Integer, nullable=True))
    
    # Add validation_status column
    op.add_column('recordings', sa.Column('validation_status', sa.String(20), nullable=False, server_default='pending'))
    
    # Add recording_status column
    op.add_column('recordings', sa.Column('recording_status', sa.String(20), nullable=False, server_default='pending_review'))
    
    # Add remarks column
    op.add_column('recordings', sa.Column('remarks', sa.Text, nullable=True))
    
    # Add validator_id column
    op.add_column('recordings', sa.Column('validator_id', sa.String(36), nullable=True))
    
    # Add validated_at column
    op.add_column('recordings', sa.Column('validated_at', sa.DateTime, nullable=True))


def downgrade():
    # Revert column changes
    op.drop_column('recordings', 'validated_at')
    op.drop_column('recordings', 'validator_id')
    op.drop_column('recordings', 'remarks')
    op.drop_column('recordings', 'validation_status')
    op.drop_column('recordings', 'fps')
    op.drop_column('recordings', 'resolution')
    op.drop_column('recordings', 'duration')
    op.drop_column('recordings', 'file_size')
    op.drop_column('recordings', 'file_url')
    op.drop_column('recordings', 'file_name')
    op.drop_column('recordings', 'background')
    op.drop_column('recordings', 'lighting_condition')
    op.drop_column('recordings', 'camera_angle')
    
    op.execute("ALTER TABLE recordings RENAME COLUMN repetition_no TO repetition")
    
    op.drop_column('collection_sessions', 'background')
    op.drop_column('collection_sessions', 'lighting_condition')
