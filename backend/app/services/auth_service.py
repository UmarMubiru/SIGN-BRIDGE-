from datetime import datetime, timedelta
from typing import Optional
from app.repositories.user_repository import UserRepository
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.schemas.user import Token, UserResponse
import uuid


class AuthService:
    def __init__(self, user_repository: UserRepository):
        self.user_repo = user_repository

    def register_user(self, name: str, email: str, password: str, role: str = "collector") -> UserResponse:
        """Register a new user"""
        # Check if user already exists
        existing_user = self.user_repo.get_user_by_email(email)
        if existing_user:
            raise ValueError("User with this email already exists")
        
        user = self.user_repo.create_user(name, email, password, role)
        return UserResponse.model_validate(user)

    def login_user(self, email: str, password: str) -> Token:
        """Authenticate user and return tokens"""
        user = self.user_repo.authenticate_user(email, password)
        if not user:
            raise ValueError("Invalid email or password")
        
        # Update last login
        self.user_repo.update_last_login(user)
        
        # Create tokens
        access_token = create_access_token(data={"sub": user.public_id})
        refresh_token = create_refresh_token(data={"sub": user.public_id})
        
        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserResponse.model_validate(user)
        )

    def refresh_tokens(self, refresh_token: str) -> Token:
        """Refresh access token using refresh token"""
        payload = decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise ValueError("Invalid refresh token")
        
        public_id = payload.get("sub")
        user = self.user_repo.get_user_by_public_id(public_id)
        if not user or not user.is_active:
            raise ValueError("User not found or inactive")
        
        # Create new tokens
        access_token = create_access_token(data={"sub": user.public_id})
        new_refresh_token = create_refresh_token(data={"sub": user.public_id})
        
        return Token(
            access_token=access_token,
            refresh_token=new_refresh_token,
            user=UserResponse.model_validate(user)
        )

    def get_current_user(self, public_id: str) -> Optional[UserResponse]:
        """Get current user by public_id from token"""
        user = self.user_repo.get_user_by_public_id(public_id)
        if user and user.is_active:
            return UserResponse.model_validate(user)
        return None
