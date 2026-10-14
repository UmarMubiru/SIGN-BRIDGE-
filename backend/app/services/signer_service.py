from datetime import datetime
from typing import Optional
from sqlalchemy.orm import Session
from app.repositories.signer_repository import SignerRepository, ConsentRepository
from app.schemas.signer import SignerCreate, SignerUpdate, SignerResponse, ConsentCreate, ConsentResponse


class SignerService:
    def __init__(self, signer_repo: SignerRepository, consent_repo: ConsentRepository, db: Session):
        self.signer_repo = signer_repo
        self.consent_repo = consent_repo
        self.db = db

    def _generate_signer_id(self) -> str:
        """Generate a unique signer ID (S001, S002, etc.)"""
        # Get all existing signers
        signers = self.signer_repo.list_signers(skip=0, limit=1000)
        
        # Extract numeric parts from existing signer IDs
        existing_numbers = []
        for signer in signers:
            if signer.signer_id and signer.signer_id.startswith('S'):
                try:
                    num = int(signer.signer_id[1:].lstrip('0'))
                    existing_numbers.append(num)
                except (ValueError, IndexError):
                    pass
        
        # Find the next available number
        next_number = 1
        while next_number in existing_numbers:
            next_number += 1
        
        # Format as S001, S002, etc.
        return f"S{next_number:03d}"

    def create_signer(self, signer_data: SignerCreate) -> SignerResponse:
        """Create a new signer with auto-generated signer ID"""
        # Auto-generate signer_id
        signer_id = self._generate_signer_id()
        
        # Add signer_id to the data
        signer_dict = signer_data.model_dump()
        signer_dict['signer_id'] = signer_id
        
        signer = self.signer_repo.create_signer(signer_dict)
        return SignerResponse.model_validate(signer)

    def get_signer(self, signer_id: str) -> Optional[SignerResponse]:
        """Get signer by ID"""
        signer = self.signer_repo.get_signer_by_id(signer_id)
        if signer:
            return SignerResponse.model_validate(signer)
        return None

    def get_signer_by_code(self, signer_code: str) -> Optional[SignerResponse]:
        """Get signer by participant code"""
        signer = self.signer_repo.get_signer_by_code(signer_code)
        if signer:
            return SignerResponse.model_validate(signer)
        return None

    def list_signers(self, skip: int = 0, limit: int = 100) -> list[SignerResponse]:
        """List all signers"""
        signers = self.signer_repo.list_signers(skip, limit)
        return [SignerResponse.model_validate(s) for s in signers]

    def update_signer(self, signer_id: str, update_data: SignerUpdate) -> Optional[SignerResponse]:
        """Update signer"""
        signer = self.signer_repo.update_signer(signer_id, update_data.model_dump(exclude_unset=True))
        if signer:
            return SignerResponse.model_validate(signer)
        return None

    def delete_signer(self, signer_id: str) -> bool:
        """Delete signer (soft delete)"""
        return self.signer_repo.delete_signer(signer_id)

    def record_consent(self, consent_data: ConsentCreate, recorded_by: str) -> ConsentResponse:
        """Record consent for a signer"""
        # Verify signer exists
        signer = self.signer_repo.get_signer_by_id(consent_data.signer_id)
        if not signer:
            raise ValueError("Signer not found")
        
        # Update signer consent status
        if consent_data.consent_status == "consented":
            signer.consent_status = "consented"
        elif consent_data.consent_status == "withdrawn":
            signer.consent_status = "withdrawn"
        
        self.db.commit()
        
        # Create consent record
        consent_dict = consent_data.model_dump()
        consent_dict['recorded_by'] = recorded_by
        consent_dict['consented_at'] = datetime.utcnow() if consent_data.consent_status == "consented" else None
        consent_dict['withdrawn_at'] = datetime.utcnow() if consent_data.consent_status == "withdrawn" else None
        
        consent = self.consent_repo.create_consent(consent_dict)
        
        return ConsentResponse.model_validate(consent)

    def get_signer_consents(self, signer_id: str) -> list[ConsentResponse]:
        """Get all consents for a signer"""
        consents = self.consent_repo.get_consent_by_signer(signer_id)
        return [ConsentResponse.model_validate(c) for c in consents]
