from sqlalchemy.orm import Session
from app.models.user import User
from app.core.security import get_password_hash, verify_password
from typing import Optional
import uuid


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_user(self, name: str, email: str, password: str, role: str = "collector") -> User:
        """Create a new user"""
        public_id = f"USR-{uuid.uuid4().hex[:8].upper()}"
        user = User(
            public_id=public_id,
            name=name,
            email=email.lower(),
            password_hash=get_password_hash(password),
            role=role,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def get_user_by_email(self, email: str) -> Optional[User]:
        """Get user by email"""
        return self.db.query(User).filter(User.email == email.lower()).first()

    def get_user_by_public_id(self, public_id: str) -> Optional[User]:
        """Get user by public_id"""
        return self.db.query(User).filter(User.public_id == public_id).first()

    def get_user_by_id(self, user_id: str) -> Optional[User]:
        """Get user by internal ID"""
        return self.db.query(User).filter(User.id == user_id).first()

    def authenticate_user(self, email: str, password: str) -> Optional[User]:
        """Authenticate user with email and password"""
        user = self.get_user_by_email(email)
        if not user:
            return None
        if not verify_password(password, user.password_hash):
            return None
        if not user.is_active:
            return None
        return user

    def update_last_login(self, user: User) -> User:
        """Update user's last login timestamp"""
        from datetime import datetime
        user.last_login_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(user)
        return user

    def list_users(self, skip: int = 0, limit: int = 100) -> list[User]:
        """List all users (admin only)"""
        return self.db.query(User).offset(skip).limit(limit).all()

    def update_user_role(self, user_id: str, role: str) -> Optional[User]:
        """Update user role (admin only)"""
        user = self.get_user_by_id(user_id)
        if user:
            user.role = role
            self.db.commit()
            self.db.refresh(user)
        return user
