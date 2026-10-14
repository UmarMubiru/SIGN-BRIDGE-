from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import get_password_hash

db = SessionLocal()
user = db.query(User).filter(User.email == 'umarmubiru330@gmail.com').first()
if user:
    user.password_hash = get_password_hash('admin123')
    db.commit()
    print('Password reset to: admin123')
else:
    print('User not found')
db.close()
