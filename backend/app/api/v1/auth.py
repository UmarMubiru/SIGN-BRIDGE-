from fastapi import APIRouter, Body, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.auth_dependencies import get_current_user
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService
from app.schemas.user import UserCreate, UserLogin, Token, UserResponse

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    user_repo = UserRepository(db)
    auth_service = AuthService(user_repo)
    
    try:
        user = auth_service.register_user(
            name=user_data.name,
            email=user_data.email,
            password=user_data.password,
            role="collector",
        )
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/login", response_model=Token)
def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """Login user and return tokens"""
    user_repo = UserRepository(db)
    auth_service = AuthService(user_repo)
    
    try:
        token = auth_service.login_user(
            email=user_data.email,
            password=user_data.password
        )
        return token
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )


@router.post("/refresh", response_model=Token)
def refresh_token(refresh_token: str = Body(..., embed=True), db: Session = Depends(get_db)):
    """Refresh access token"""
    user_repo = UserRepository(db)
    auth_service = AuthService(user_repo)
    
    try:
        token = auth_service.refresh_tokens(refresh_token)
        return token
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )


@router.get("/me", response_model=UserResponse)
def get_me(current_user: UserResponse = Depends(get_current_user)):
    """Get current user info"""
    return current_user
