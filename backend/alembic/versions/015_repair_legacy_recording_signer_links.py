"""Repair legacy recording signer references using their collection session.

Revision ID: 015
Revises: 014
"""
from alembic import op


revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade():
    # Older SQLite records stored the public signer code (for example S001)
    # in recordings.signer_id. PostgreSQL uses the signer's UUID there. The
    # recording's session provides an unambiguous signer relationship; only
    # rewrite when the legacy code agrees with that signer's public code.
    op.execute(
        """
        UPDATE recordings AS recording
        SET signer_id = signer.id
        FROM collection_sessions AS session
        JOIN signers AS signer ON signer.id = session.signer_id
        WHERE recording.session_id = session.id
          AND recording.signer_id = signer.signer_id
          AND recording.signer_id <> signer.id
        """
    )


def downgrade():
    # Keep repaired UUID references valid; reversing would recreate orphaned
    # recording rows and break joins on the current schema.
    pass
