"""create sessions and recordings tables

Revision ID: 004
Revises: 003
Create Date: 2025-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '004'
down_revision = '003'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create collection_sessions table
    op.create_table(
        'collection_sessions',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('public_id', sa.String(20), nullable=False),
        sa.Column('signer_id', sa.String(36), nullable=False),
        sa.Column('collector_id', sa.String(36), nullable=False),
        sa.Column('venue', sa.String(100), nullable=False, server_default='Makerere University / MUDSA'),
        sa.Column('protocol_version', sa.String(20), nullable=False, server_default='v1'),
        sa.Column('device_info', sa.Text(), nullable=True),
        sa.Column('camera_info', sa.Text(), nullable=True),
        sa.Column('status', sa.String(20), nullable=False, server_default='created'),
        sa.Column('started_at', sa.DateTime(), nullable=True),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
        sa.Column('total_recordings', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('successful_recordings', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime()),
    )
    op.create_index('ix_collection_sessions_public_id', 'collection_sessions', ['public_id'], unique=True)
    
    # Create recordings table
    op.create_table(
        'recordings',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('public_id', sa.String(20), nullable=False),
        sa.Column('client_id', sa.String(50), nullable=False),
        sa.Column('session_id', sa.String(36), nullable=False),
        sa.Column('signer_id', sa.String(36), nullable=False),
        sa.Column('sign_id', sa.String(36), nullable=False),
        sa.Column('repetition', sa.Integer(), nullable=False),
        sa.Column('preset', sa.String(50), nullable=False),
        sa.Column('status', sa.String(20), nullable=False, server_default='created'),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime()),
    )
    op.create_index('ix_recordings_public_id', 'recordings', ['public_id'], unique=True)
    op.create_index('ix_recordings_client_id', 'recordings', ['client_id'], unique=True)
    
    # Create recording_conditions table
    op.create_table(
        'recording_conditions',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('recording_id', sa.String(36), nullable=False),
        sa.Column('lighting', sa.String(50), nullable=False),
        sa.Column('background', sa.String(50), nullable=False),
        sa.Column('distance_cm', sa.Integer(), nullable=True),
        sa.Column('camera_position', sa.String(50), nullable=True),
        sa.Column('camera_height', sa.String(50), nullable=True),
        sa.Column('device_facing', sa.String(50), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
    )
    op.create_index('ix_recording_conditions_recording_id', 'recording_conditions', ['recording_id'], unique=True)
    
    # Create videos table
    op.create_table(
        'videos',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('recording_id', sa.String(36), nullable=False),
        sa.Column('filename', sa.String(255), nullable=False),
        sa.Column('storage_path', sa.String(500), nullable=False),
        sa.Column('mime_type', sa.String(100), nullable=False),
        sa.Column('file_size_bytes', sa.Integer(), nullable=False),
        sa.Column('duration_seconds', sa.Integer(), nullable=True),
        sa.Column('width', sa.Integer(), nullable=True),
        sa.Column('height', sa.Integer(), nullable=True),
        sa.Column('fps', sa.Integer(), nullable=True),
        sa.Column('codec', sa.String(50), nullable=True),
        sa.Column('sha256_checksum', sa.String(64), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
    )
    op.create_index('ix_videos_recording_id', 'videos', ['recording_id'], unique=True)
    
    # Create recording_reviews table
    op.create_table(
        'recording_reviews',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('recording_id', sa.String(36), nullable=False),
        sa.Column('lighting_adequate', sa.Boolean(), nullable=True),
        sa.Column('background_clear', sa.Boolean(), nullable=True),
        sa.Column('signer_visible', sa.Boolean(), nullable=True),
        sa.Column('hands_visible', sa.Boolean(), nullable=True),
        sa.Column('movement_clear', sa.Boolean(), nullable=True),
        sa.Column('audio_clear', sa.Boolean(), nullable=True),
        sa.Column('status', sa.String(20), nullable=False),
        sa.Column('reviewed_by', sa.String(36), nullable=True),
        sa.Column('reviewed_at', sa.DateTime(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime()),
    )
    op.create_index('ix_recording_reviews_recording_id', 'recording_reviews', ['recording_id'], unique=True)
    
    # Create sign_validations table
    op.create_table(
        'sign_validations',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('recording_id', sa.String(36), nullable=False),
        sa.Column('is_correct', sa.Boolean(), nullable=True),
        sa.Column('is_unclear', sa.Boolean(), nullable=True),
        sa.Column('confidence_score', sa.Integer(), nullable=True),
        sa.Column('validated_by', sa.String(36), nullable=True),
        sa.Column('validated_at', sa.DateTime(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime()),
    )
    op.create_index('ix_sign_validations_recording_id', 'sign_validations', ['recording_id'], unique=True)


def downgrade() -> None:
    op.drop_table('sign_validations')
    op.drop_table('recording_reviews')
    op.drop_table('videos')
    op.drop_table('recording_conditions')
    op.drop_table('recordings')
    op.drop_index('ix_collection_sessions_public_id', table_name='collection_sessions')
    op.drop_table('collection_sessions')
