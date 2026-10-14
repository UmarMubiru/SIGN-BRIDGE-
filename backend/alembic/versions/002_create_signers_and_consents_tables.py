"""create signers and consents tables

Revision ID: 002
Revises: 001
Create Date: 2025-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create signers table
    op.create_table(
        'signers',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('signer_id', sa.String(50), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('category', sa.String(50), nullable=False),
        sa.Column('age', sa.Integer(), nullable=True),
        sa.Column('gender', sa.String(20), nullable=True),
        sa.Column('education_level', sa.String(50), nullable=True),
        sa.Column('consent_status', sa.String(20), nullable=False, server_default='pending'),
        sa.Column('status', sa.String(20), nullable=False, server_default='active'),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime()),
    )
    op.create_index('ix_signers_signer_id', 'signers', ['signer_id'], unique=True)
    
    # Create consents table (without foreign keys for SQLite compatibility)
    op.create_table(
        'consents',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('signer_id', sa.String(36), nullable=False),
        sa.Column('consent_version', sa.String(20), nullable=False),
        sa.Column('consent_status', sa.String(20), nullable=False),
        sa.Column('consented_at', sa.DateTime(), nullable=True),
        sa.Column('recorded_by', sa.String(36), nullable=True),
        sa.Column('withdrawn_at', sa.DateTime(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
    )


def downgrade() -> None:
    op.drop_table('consents')
    op.drop_index('ix_signers_signer_id', table_name='signers')
    op.drop_table('signers')
