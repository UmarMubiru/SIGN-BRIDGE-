from sqlalchemy.orm import Session
from app.models.session import CollectionSession, SessionStatus
from typing import Optional, List
import uuid
from datetime import datetime


class SessionRepository:
    def __init__(self, db: Session):
        self.db = db

    def create_session(
        self,
        signer_id: str,
        collector_id: str,
        venue: str = "Makerere University / MUDSA",
        protocol_version: str = "v1",
        lighting_condition: str = "Daylight",
        background: str = "Plain Wall — Light",
        device_info: Optional[str] = None,
        camera_info: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> CollectionSession:
        """Create a new collection session"""
        public_id = f"SES-{uuid.uuid4().hex[:8].upper()}"
        session = CollectionSession(
            public_id=public_id,
            signer_id=signer_id,
            collector_id=collector_id,
            venue=venue,
            protocol_version=protocol_version,
            lighting_condition=lighting_condition,
            background=background,
            device_info=device_info,
            camera_info=camera_info,
            status=SessionStatus.CREATED,
            notes=notes,
        )
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session

    def get_session_by_id(self, session_id: str) -> Optional[CollectionSession]:
        """Get session by internal ID"""
        return self.db.query(CollectionSession).filter(CollectionSession.id == session_id).first()

    def get_session_by_public_id(self, public_id: str) -> Optional[CollectionSession]:
        """Get session by public ID"""
        return self.db.query(CollectionSession).filter(CollectionSession.public_id == public_id).first()

    def list_sessions(
        self,
        skip: int = 0,
        limit: int = 100,
        collector_id: Optional[str] = None,
        signer_id: Optional[str] = None,
        status: Optional[SessionStatus] = None,
    ) -> List[CollectionSession]:
        """List sessions with optional filters"""
        query = self.db.query(CollectionSession)
        
        if collector_id:
            query = query.filter(CollectionSession.collector_id == collector_id)
        if signer_id:
            query = query.filter(CollectionSession.signer_id == signer_id)
        if status:
            query = query.filter(CollectionSession.status == status)
        
        return query.order_by(CollectionSession.created_at.desc()).offset(skip).limit(limit).all()

    def update_session_status(self, session_id: str, status: SessionStatus) -> Optional[CollectionSession]:
        """Update session status"""
        session = self.get_session_by_id(session_id)
        if session:
            session.status = status
            if status == SessionStatus.IN_PROGRESS and not session.started_at:
                session.started_at = datetime.utcnow()
            if status == SessionStatus.COMPLETED and not session.completed_at:
                session.completed_at = datetime.utcnow()
            self.db.commit()
            self.db.refresh(session)
        return session

    def update_session(
        self,
        session_id: str,
        venue: Optional[str] = None,
        device_info: Optional[str] = None,
        camera_info: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> Optional[CollectionSession]:
        """Update session metadata"""
        session = self.get_session_by_id(session_id)
        if session:
            if venue is not None:
                session.venue = venue
            if device_info is not None:
                session.device_info = device_info
            if camera_info is not None:
                session.camera_info = camera_info
            if notes is not None:
                session.notes = notes
            self.db.commit()
            self.db.refresh(session)
        return session

    def increment_recording_count(self, session_id: str, successful: bool = True) -> Optional[CollectionSession]:
        """Increment recording counters"""
        session = self.get_session_by_id(session_id)
        if session:
            session.total_recordings += 1
            if successful:
                session.successful_recordings += 1
            self.db.commit()
            self.db.refresh(session)
        return session

    def delete_session(self, session_id: str) -> bool:
        """Delete a session (soft delete by status)"""
        session = self.get_session_by_id(session_id)
        if session:
            session.status = SessionStatus.CANCELLED
            self.db.commit()
            return True
        return False
