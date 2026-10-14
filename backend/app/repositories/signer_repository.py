from sqlalchemy.orm import Session
from app.models.signer import Signer
from app.models.consent import Consent
from typing import Optional
import uuid


class SignerRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_signer(self, signer_data: dict) -> Signer:
        """Create a new signer"""
        signer = Signer(**signer_data)
        self.db.add(signer)
        self.db.commit()
        self.db.refresh(signer)
        return signer

    def get_signer_by_id(self, signer_id: str) -> Optional[Signer]:
        """Get signer by internal ID"""
        return self.db.query(Signer).filter(Signer.id == signer_id).first()

    def get_signer_by_code(self, signer_code: str) -> Optional[Signer]:
        """Get signer by participant code (S001, etc.)"""
        return self.db.query(Signer).filter(Signer.signer_id == signer_code).first()

    def list_signers(self, skip: int = 0, limit: int = 100) -> list[Signer]:
        """List all signers"""
        return self.db.query(Signer).offset(skip).limit(limit).all()

    def update_signer(self, signer_id: str, update_data: dict) -> Optional[Signer]:
        """Update signer"""
        signer = self.get_signer_by_id(signer_id)
        if signer:
            for key, value in update_data.items():
                if hasattr(signer, key) and value is not None:
                    setattr(signer, key, value)
            self.db.commit()
            self.db.refresh(signer)
        return signer

    def delete_signer(self, signer_id: str) -> bool:
        """Delete signer (soft delete by setting status to inactive)"""
        signer = self.get_signer_by_id(signer_id)
        if signer:
            signer.status = "inactive"
            self.db.commit()
            return True
        return False


class ConsentRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_consent(self, consent_data: dict) -> Consent:
        """Create a new consent record"""
        consent = Consent(**consent_data)
        self.db.add(consent)
        self.db.commit()
        self.db.refresh(consent)
        return consent

    def get_consent_by_id(self, consent_id: str) -> Optional[Consent]:
        """Get consent by ID"""
        return self.db.query(Consent).filter(Consent.id == consent_id).first()

    def get_consent_by_signer(self, signer_id: str) -> list[Consent]:
        """Get all consents for a signer"""
        return self.db.query(Consent).filter(Consent.signer_id == signer_id).all()

    def get_latest_consent(self, signer_id: str) -> Optional[Consent]:
        """Get the latest consent for a signer"""
        return self.db.query(Consent).filter(Consent.signer_id == signer_id).order_by(Consent.created_at.desc()).first()

    def list_consents(self, skip: int = 0, limit: int = 100) -> list[Consent]:
        """List all consents"""
        return self.db.query(Consent).offset(skip).limit(limit).all()
