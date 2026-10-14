"""create signs and sign_versions tables

Revision ID: 003
Revises: 002
Create Date: 2025-01-01 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '003'
down_revision = '002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create signs table
    op.create_table(
        'signs',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('sign_code', sa.String(50), nullable=False),
        sa.Column('gloss', sa.String(100), nullable=False),
        sa.Column('display_name', sa.String(100), nullable=False),
        sa.Column('category', sa.String(50), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('instruction', sa.Text(), nullable=True),
        sa.Column('active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('target_repetitions', sa.Integer(), nullable=False, server_default='10'),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime()),
    )
    op.create_index('ix_signs_sign_code', 'signs', ['sign_code'], unique=True)
    
    # Create sign_versions table
    op.create_table(
        'sign_versions',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('sign_id', sa.String(36), nullable=False),
        sa.Column('version', sa.String(20), nullable=False),
        sa.Column('instruction', sa.Text(), nullable=True),
        sa.Column('definition', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('created_by', sa.String(36), nullable=True),
    )


def downgrade() -> None:
    op.drop_table('sign_versions')
    op.drop_index('ix_signs_sign_code', table_name='signs')
    op.drop_table('signs')
