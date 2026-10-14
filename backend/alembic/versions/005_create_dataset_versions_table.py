"""create dataset_versions table

Revision ID: 005
Revises: 004
Create Date: 2025-01-21

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '005'
down_revision = '004'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'dataset_versions',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('version_number', sa.String(50), unique=True, nullable=False, index=True),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('created_by', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('total_recordings', sa.Integer(), default=0, nullable=False),
        sa.Column('included_recordings', sa.Integer(), default=0, nullable=False),
        sa.Column('excluded_recordings', sa.Integer(), default=0, nullable=False),
        sa.Column('export_config', sa.JSON(), nullable=True),
    )


def downgrade():
    op.drop_table('dataset_versions')
