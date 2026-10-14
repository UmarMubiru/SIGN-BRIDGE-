from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.api.v1.auth import get_current_user
from app.repositories.session_repository import SessionRepository
from app.services.session_service import SessionService
from app.schemas.session import SessionCreate, SessionUpdate, SessionResponse, SessionStatus
from app.schemas.user import UserResponse

router = APIRouter()


def get_session_service(db: Session = Depends(get_db)) -> SessionService:
    """Dependency to get session service"""
    session_repo = SessionRepository(db)
    return SessionService(session_repo)


@router.post("/", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
def create_session(
    session_data: SessionCreate,
    service: SessionService = Depends(get_session_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Create a new collection session"""
    try:
        session = service.create_session(session_data, current_user.id)
        return session
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/", response_model=list[SessionResponse])
def list_sessions(
    skip: int = 0,
    limit: int = 100,
    signer_id: str = None,
    status: SessionStatus = None,
    service: SessionService = Depends(get_session_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """List sessions (filter by current user's sessions unless admin)"""
    collector_id = current_user.id if current_user.role != "admin" else None
    return service.list_sessions(
        skip=skip,
        limit=limit,
        collector_id=collector_id,
        signer_id=signer_id,
        status=status,
    )


@router.get("/{session_id}", response_model=SessionResponse)
def get_session(
    session_id: str,
    service: SessionService = Depends(get_session_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get session by ID"""
    session = service.get_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    return session


@router.patch("/{session_id}", response_model=SessionResponse)
def update_session(
    session_id: str,
    update_data: SessionUpdate,
    service: SessionService = Depends(get_session_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Update session metadata"""
    session = service.update_session(session_id, update_data)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    return session


@router.post("/{session_id}/start", response_model=SessionResponse)
def start_session(
    session_id: str,
    service: SessionService = Depends(get_session_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Start a session"""
    session = service.start_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    return session


@router.post("/{session_id}/complete", response_model=SessionResponse)
def complete_session(
    session_id: str,
    service: SessionService = Depends(get_session_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Complete a session"""
    session = service.complete_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    return session


@router.post("/{session_id}/cancel", response_model=SessionResponse)
def cancel_session(
    session_id: str,
    service: SessionService = Depends(get_session_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Cancel a session"""
    session = service.cancel_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found"
        )
    return session
