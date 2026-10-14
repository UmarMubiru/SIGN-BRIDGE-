from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.api.v1.auth import get_current_user
from app.repositories.signer_repository import SignerRepository, ConsentRepository
from app.services.signer_service import SignerService
from app.schemas.signer import SignerCreate, SignerUpdate, SignerResponse, ConsentCreate, ConsentResponse
from app.schemas.user import UserResponse

router = APIRouter()


def get_signer_service(db: Session = Depends(get_db)) -> SignerService:
    """Dependency to get signer service"""
    signer_repo = SignerRepository(db)
    consent_repo = ConsentRepository(db)
    return SignerService(signer_repo, consent_repo, db)


@router.post("/", response_model=SignerResponse, status_code=status.HTTP_201_CREATED)
def create_signer(
    signer_data: SignerCreate,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Create a new signer"""
    try:
        signer = service.create_signer(signer_data)
        return signer
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/", response_model=list[SignerResponse])
def list_signers(
    skip: int = 0,
    limit: int = 100,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """List all signers"""
    return service.list_signers(skip, limit)


@router.get("/{signer_id}", response_model=SignerResponse)
def get_signer(
    signer_id: str,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get signer by ID"""
    signer = service.get_signer(signer_id)
    if not signer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Signer not found"
        )
    return signer


@router.get("/code/{signer_code}", response_model=SignerResponse)
def get_signer_by_code(
    signer_code: str,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get signer by participant code"""
    signer = service.get_signer_by_code(signer_code)
    if not signer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Signer not found"
        )
    return signer


@router.patch("/{signer_id}", response_model=SignerResponse)
def update_signer(
    signer_id: str,
    update_data: SignerUpdate,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Update signer"""
    signer = service.update_signer(signer_id, update_data)
    if not signer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Signer not found"
        )
    return signer


@router.delete("/{signer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_signer(
    signer_id: str,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Delete signer (soft delete)"""
    success = service.delete_signer(signer_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Signer not found"
        )


@router.post("/{signer_id}/consent", response_model=ConsentResponse)
def record_consent(
    signer_id: str,
    consent_data: ConsentCreate,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Record consent for a signer"""
    try:
        consent_data.signer_id = signer_id
        consent = service.record_consent(consent_data, current_user.id)
        return consent
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/{signer_id}/consent", response_model=list[ConsentResponse])
def get_signer_consents(
    signer_id: str,
    service: SignerService = Depends(get_signer_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get all consents for a signer"""
    return service.get_signer_consents(signer_id)
