from sqlalchemy.orm import Session
from app.models.sign import Sign, SignVersion
from typing import Optional
import uuid


class SignRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_sign(self, sign_data: dict) -> Sign:
        """Create a new sign"""
        sign = Sign(**sign_data)
        self.db.add(sign)
        self.db.commit()
        self.db.refresh(sign)
        return sign

    def get_sign_by_id(self, sign_id: str) -> Optional[Sign]:
        """Get sign by internal ID"""
        return self.db.query(Sign).filter(Sign.id == sign_id).first()

    def get_sign_by_code(self, sign_code: str) -> Optional[Sign]:
        """Get sign by sign code (HELLO, THANK_YOU, etc.)"""
        return self.db.query(Sign).filter(Sign.sign_code == sign_code).first()

    def list_signs(self, skip: int = 0, limit: int = 100, active_only: bool = True) -> list[Sign]:
        """List all signs"""
        query = self.db.query(Sign)
        if active_only:
            query = query.filter(Sign.active == True)
        return query.offset(skip).limit(limit).all()

    def update_sign(self, sign_id: str, update_data: dict) -> Optional[Sign]:
        """Update sign"""
        sign = self.get_sign_by_id(sign_id)
        if sign:
            for key, value in update_data.items():
                if hasattr(sign, key) and value is not None:
                    setattr(sign, key, value)
            self.db.commit()
            self.db.refresh(sign)
        return sign

    def delete_sign(self, sign_id: str) -> bool:
        """Delete sign (soft delete by setting active to False)"""
        sign = self.get_sign_by_id(sign_id)
        if sign:
            sign.active = False
            self.db.commit()
            return True
        return False


class SignVersionRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_sign_version(self, version_data: dict) -> SignVersion:
        """Create a new sign version"""
        version = SignVersion(**version_data)
        self.db.add(version)
        self.db.commit()
        self.db.refresh(version)
        return version

    def get_version_by_id(self, version_id: str) -> Optional[SignVersion]:
        """Get version by ID"""
        return self.db.query(SignVersion).filter(SignVersion.id == version_id).first()

    def get_sign_versions(self, sign_id: str) -> list[SignVersion]:
        """Get all versions for a sign"""
        return self.db.query(SignVersion).filter(SignVersion.sign_id == sign_id).all()

    def get_latest_version(self, sign_id: str) -> Optional[SignVersion]:
        """Get the latest version for a sign"""
        return self.db.query(SignVersion).filter(SignVersion.sign_id == sign_id).order_by(SignVersion.created_at.desc()).first()
