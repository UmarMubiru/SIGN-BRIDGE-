from app.repositories.session_repository import SessionRepository
from app.schemas.session import SessionCreate, SessionUpdate, SessionResponse, SessionStatus
from typing import Optional, List


class SessionService:
    def __init__(self, session_repo: SessionRepository):
        self.session_repo = session_repo

    def create_session(
        self,
        session_data: SessionCreate,
        collector_id: str,
    ) -> SessionResponse:
        """Create a new collection session"""
        session = self.session_repo.create_session(
            signer_id=session_data.signer_id,
            collector_id=collector_id,
            venue=session_data.venue,
            protocol_version=session_data.protocol_version,
            lighting_condition=session_data.lighting_condition,
            background=session_data.background,
            device_info=session_data.device_info,
            camera_info=session_data.camera_info,
            notes=session_data.notes,
        )
        return SessionResponse.model_validate(session)

    def get_session(self, session_id: str) -> Optional[SessionResponse]:
        """Get session by ID"""
        session = self.session_repo.get_session_by_id(session_id)
        if session:
            return SessionResponse.model_validate(session)
        return None

    def get_session_by_public_id(self, public_id: str) -> Optional[SessionResponse]:
        """Get session by public ID"""
        session = self.session_repo.get_session_by_public_id(public_id)
        if session:
            return SessionResponse.model_validate(session)
        return None

    def list_sessions(
        self,
        skip: int = 0,
        limit: int = 100,
        collector_id: Optional[str] = None,
        signer_id: Optional[str] = None,
        status: Optional[SessionStatus] = None,
    ) -> List[SessionResponse]:
        """List sessions with optional filters"""
        sessions = self.session_repo.list_sessions(
            skip=skip,
            limit=limit,
            collector_id=collector_id,
            signer_id=signer_id,
            status=status,
        )
        return [SessionResponse.model_validate(session) for session in sessions]

    def update_session_status(self, session_id: str, status: SessionStatus) -> Optional[SessionResponse]:
        """Update session status"""
        session = self.session_repo.update_session_status(session_id, status)
        if session:
            return SessionResponse.model_validate(session)
        return None

    def update_session(self, session_id: str, update_data: SessionUpdate) -> Optional[SessionResponse]:
        """Update session metadata"""
        session = self.session_repo.update_session(
            session_id=session_id,
            venue=update_data.venue,
            device_info=update_data.device_info,
            camera_info=update_data.camera_info,
            notes=update_data.notes,
        )
        if session:
            return SessionResponse.model_validate(session)
        return None

    def start_session(self, session_id: str) -> Optional[SessionResponse]:
        """Start a session (change status to IN_PROGRESS)"""
        return self.update_session_status(session_id, SessionStatus.IN_PROGRESS)

    def complete_session(self, session_id: str) -> Optional[SessionResponse]:
        """Complete a session (change status to COMPLETED)"""
        return self.update_session_status(session_id, SessionStatus.COMPLETED)

    def cancel_session(self, session_id: str) -> Optional[SessionResponse]:
        """Cancel a session (change status to CANCELLED)"""
        return self.update_session_status(session_id, SessionStatus.CANCELLED)

    def increment_recording_count(self, session_id: str, successful: bool = True) -> Optional[SessionResponse]:
        """Increment recording counters"""
        session = self.session_repo.increment_recording_count(session_id, successful)
        if session:
            return SessionResponse.model_validate(session)
        return None
