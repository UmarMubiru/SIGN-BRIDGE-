from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import decode_token
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService
from app.schemas.user import UserResponse

security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> UserResponse:
    """Dependency to get current authenticated user"""
    token = credentials.credentials
    payload = decode_token(token)
    public_id = payload.get("sub") if payload else None
    token_version = payload.get("ver") if payload else None
    if (
        not payload
        or payload.get("type") != "access"
        or not isinstance(public_id, str)
        or not isinstance(token_version, int)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

    user_repo = UserRepository(db)
    auth_service = AuthService(user_repo)
    user = auth_service.get_current_user(public_id, token_version)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return user
