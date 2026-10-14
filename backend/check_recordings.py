from app.core.database import SessionLocal
from app.models.recording import Recording

db = SessionLocal()
recordings = db.query(Recording).all()
print('Recordings:')
for r in recordings:
    print(f'ID: {r.id}, file_name: {r.file_name}, file_url: {r.file_url}')
db.close()
