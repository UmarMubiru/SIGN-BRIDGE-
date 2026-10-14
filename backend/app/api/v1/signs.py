from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.api.v1.auth import get_current_user
from app.repositories.sign_repository import SignRepository, SignVersionRepository
from app.services.sign_service import SignService
from app.schemas.sign import SignCreate, SignUpdate, SignResponse, SignVersionCreate, SignVersionResponse
from app.schemas.user import UserResponse

router = APIRouter()


def get_sign_service(db: Session = Depends(get_db)) -> SignService:
    """Dependency to get sign service"""
    sign_repo = SignRepository(db)
    version_repo = SignVersionRepository(db)
    return SignService(sign_repo, version_repo)


@router.post("/seed", response_model=list[SignResponse])
def seed_approved_signs(
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Seed the 10 approved signs (admin only)"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can seed signs"
        )
    return service.seed_approved_signs()


@router.post("/", response_model=SignResponse, status_code=status.HTTP_201_CREATED)
def create_sign(
    sign_data: SignCreate,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Create a new sign"""
    try:
        sign = service.create_sign(sign_data)
        return sign
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/", response_model=list[SignResponse])
def list_signs(
    skip: int = 0,
    limit: int = 100,
    active_only: bool = True,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """List all signs"""
    return service.list_signs(skip, limit, active_only)


@router.get("/{sign_id}", response_model=SignResponse)
def get_sign(
    sign_id: str,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get sign by ID"""
    sign = service.get_sign(sign_id)
    if not sign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sign not found"
        )
    return sign


@router.get("/code/{sign_code}", response_model=SignResponse)
def get_sign_by_code(
    sign_code: str,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get sign by code"""
    sign = service.get_sign_by_code(sign_code)
    if not sign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sign not found"
        )
    return sign


@router.patch("/{sign_id}", response_model=SignResponse)
def update_sign(
    sign_id: str,
    update_data: SignUpdate,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Update sign"""
    sign = service.update_sign(sign_id, update_data)
    if not sign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sign not found"
        )
    return sign


@router.delete("/{sign_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_sign(
    sign_id: str,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Delete sign (soft delete)"""
    success = service.delete_sign(sign_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sign not found"
        )


@router.post("/{sign_id}/versions", response_model=SignVersionResponse)
def create_sign_version(
    sign_id: str,
    version_data: SignVersionCreate,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Create a new sign version"""
    try:
        version_data.sign_id = sign_id
        version = service.create_sign_version(version_data, current_user.id)
        return version
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/{sign_id}/versions", response_model=list[SignVersionResponse])
def get_sign_versions(
    sign_id: str,
    service: SignService = Depends(get_sign_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get all versions for a sign"""
    return service.get_sign_versions(sign_id)
