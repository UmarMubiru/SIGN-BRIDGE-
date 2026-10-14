from app.core.database import engine
from sqlalchemy import text

with engine.connect() as conn:
    conn.execute(text('ALTER TABLE recordings ADD COLUMN recording_status VARCHAR(20) DEFAULT "pending_review"'))
    conn.commit()
    print('Column added successfully')
