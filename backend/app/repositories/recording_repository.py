from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.models.recording import Recording
from typing import Optional, List
import uuid


class RecordingRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_recording(self, recording_data: dict) -> Recording:
        """Create a new recording"""
        recording = Recording(**recording_data)
        self.db.add(recording)
        self.db.commit()
        self.db.refresh(recording)
        return recording

    def get_recording_by_id(self, recording_id: str) -> Optional[Recording]:
        """Get recording by internal ID"""
        return self.db.query(Recording).filter(Recording.id == recording_id).first()

    def get_recording_by_public_id(self, public_id: str) -> Optional[Recording]:
        """Get recording by public ID"""
        return self.db.query(Recording).filter(Recording.public_id == public_id).first()

    def list_recordings(
        self,
        skip: int = 0,
        limit: int = 100,
        session_id: str = None,
        sign_id: str = None,
        signer_id: str = None
    ) -> List[Recording]:
        """List recordings with optional filters"""
        query = self.db.query(Recording)
        
        if session_id:
            query = query.filter(Recording.session_id == session_id)
        if sign_id:
            query = query.filter(Recording.sign_id == sign_id)
        if signer_id:
            query = query.filter(Recording.signer_id == signer_id)
        
        return query.order_by(desc(Recording.created_at), desc(Recording.id)).offset(skip).limit(limit).all()

    def update_recording(self, recording_id: str, update_data: dict) -> Optional[Recording]:
        """Update recording"""
        recording = self.get_recording_by_id(recording_id)
        if recording:
            for key, value in update_data.items():
                if hasattr(recording, key):
                    setattr(recording, key, value)
            self.db.commit()
            self.db.refresh(recording)
        return recording

    def delete_recording(self, recording_id: str) -> bool:
        """Delete recording"""
        recording = self.get_recording_by_id(recording_id)
        if recording:
            self.db.delete(recording)
            self.db.commit()
            return True
        return False
