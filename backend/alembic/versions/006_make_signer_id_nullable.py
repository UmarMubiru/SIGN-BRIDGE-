"""make_signer_id_nullable

Revision ID: 006
Revises: 005
Create Date: 2025-01-15

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import sqlite


# revision identifiers, used by Alembic.
revision = '006'
down_revision = '005'
branch_labels = None
depends_on = None


def upgrade():
    # SQLite doesn't support ALTER COLUMN directly, so we need to recreate the table
    # Create new table with nullable signer_id
    op.execute("""
        CREATE TABLE signers_new (
            id VARCHAR(36) PRIMARY KEY,
            signer_id VARCHAR(50) UNIQUE,
            name VARCHAR(100) NOT NULL,
            category VARCHAR(50) NOT NULL,
            age INTEGER,
            gender VARCHAR(20),
            education_level VARCHAR(50),
            consent_status VARCHAR(20) DEFAULT 'pending' NOT NULL,
            status VARCHAR(20) DEFAULT 'active' NOT NULL,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP
        )
    """)

    # Copy data from old table
    op.execute("""
        INSERT INTO signers_new (id, signer_id, name, category, age, gender, education_level, consent_status, status, notes, created_at, updated_at)
        SELECT id, signer_id, name, category, age, gender, education_level, consent_status, status, notes, created_at, updated_at
        FROM signers
    """)

    # Drop old table
    op.execute("DROP TABLE signers")

    # Rename new table
    op.execute("ALTER TABLE signers_new RENAME TO signers")

    # Recreate index
    op.execute("CREATE INDEX ix_signers_signer_id ON signers (signer_id)")


def downgrade():
    # Recreate table with NOT NULL signer_id
    op.execute("""
        CREATE TABLE signers_new (
            id VARCHAR(36) PRIMARY KEY,
            signer_id VARCHAR(50) UNIQUE NOT NULL,
            name VARCHAR(100) NOT NULL,
            category VARCHAR(50) NOT NULL,
            age INTEGER,
            gender VARCHAR(20),
            education_level VARCHAR(50),
            consent_status VARCHAR(20) DEFAULT 'pending' NOT NULL,
            status VARCHAR(20) DEFAULT 'active' NOT NULL,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP
        )
    """)

    # Copy data
    op.execute("""
        INSERT INTO signers_new (id, signer_id, name, category, age, gender, education_level, consent_status, status, notes, created_at, updated_at)
        SELECT id, signer_id, name, category, age, gender, education_level, consent_status, status, notes, created_at, updated_at
        FROM signers
    """)

    # Drop old table
    op.execute("DROP TABLE signers")

    # Rename new table
    op.execute("ALTER TABLE signers_new RENAME TO signers")

    # Recreate index
    op.execute("CREATE INDEX ix_signers_signer_id ON signers (signer_id)")
