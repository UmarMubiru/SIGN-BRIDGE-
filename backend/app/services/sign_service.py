from typing import Optional
from sqlalchemy.orm import Session
from app.repositories.sign_repository import SignRepository, SignVersionRepository
from app.schemas.sign import SignCreate, SignUpdate, SignResponse, SignVersionCreate, SignVersionResponse


class SignService:
    def __init__(self, sign_repo: SignRepository, version_repo: SignVersionRepository):
        self.sign_repo = sign_repo
        self.version_repo = version_repo

    def create_sign(self, sign_data: SignCreate) -> SignResponse:
        """Create a new sign"""
        # Check if sign_code already exists
        existing = self.sign_repo.get_sign_by_code(sign_data.sign_code)
        if existing:
            raise ValueError(f"Sign with code {sign_data.sign_code} already exists")
        
        sign = self.sign_repo.create_sign(sign_data.model_dump())
        return SignResponse.model_validate(sign)

    def get_sign(self, sign_id: str) -> Optional[SignResponse]:
        """Get sign by ID"""
        sign = self.sign_repo.get_sign_by_id(sign_id)
        if sign:
            return SignResponse.model_validate(sign)
        return None

    def get_sign_by_code(self, sign_code: str) -> Optional[SignResponse]:
        """Get sign by code"""
        sign = self.sign_repo.get_sign_by_code(sign_code)
        if sign:
            return SignResponse.model_validate(sign)
        return None

    def list_signs(self, skip: int = 0, limit: int = 100, active_only: bool = True) -> list[SignResponse]:
        """List all signs"""
        signs = self.sign_repo.list_signs(skip, limit, active_only)
        return [SignResponse.model_validate(s) for s in signs]

    def update_sign(self, sign_id: str, update_data: SignUpdate) -> Optional[SignResponse]:
        """Update sign"""
        sign = self.sign_repo.update_sign(sign_id, update_data.model_dump(exclude_unset=True))
        if sign:
            return SignResponse.model_validate(sign)
        return None

    def delete_sign(self, sign_id: str) -> bool:
        """Delete sign (soft delete)"""
        return self.sign_repo.delete_sign(sign_id)

    def create_sign_version(self, version_data: SignVersionCreate, created_by: str) -> SignVersionResponse:
        """Create a new sign version"""
        # Verify sign exists
        sign = self.sign_repo.get_sign_by_id(version_data.sign_id)
        if not sign:
            raise ValueError("Sign not found")
        
        version_dict = version_data.model_dump()
        version_dict['created_by'] = created_by
        
        version = self.version_repo.create_sign_version(version_dict)
        return SignVersionResponse.model_validate(version)

    def get_sign_versions(self, sign_id: str) -> list[SignVersionResponse]:
        """Get all versions for a sign"""
        versions = self.version_repo.get_sign_versions(sign_id)
        return [SignVersionResponse.model_validate(v) for v in versions]

    def seed_approved_signs(self) -> list[SignResponse]:
        """Seed the 10 approved signs with target_formats=3"""
        # NOTE: These are placeholder labels - should be replaced with actual approved signs
        # from the existing instrument/source-of-truth as per the plan
        approved_signs = [
            {
                "sign_code": "HELLO",
                "gloss": "hello",
                "display_name": "Hello",
                "category": "greeting",
                "description": "Standard greeting sign",
                "instruction": "Wave hand with palm facing outward",
                "target_formats": 3
            },
            {
                "sign_code": "THANK_YOU",
                "gloss": "thank_you",
                "display_name": "Thank You",
                "category": "expression",
                "description": "Expression of gratitude",
                "instruction": "Touch chin with fingertips, move hand forward",
                "target_formats": 3
            },
            {
                "sign_code": "PLEASE",
                "gloss": "please",
                "display_name": "Please",
                "category": "politeness",
                "description": "Polite request marker",
                "instruction": "Circular motion on chest with flat hand",
                "target_formats": 3
            },
            {
                "sign_code": "SORRY",
                "gloss": "sorry",
                "display_name": "Sorry",
                "category": "apology",
                "description": "Expression of apology",
                "instruction": "Rub chest in circular motion with fist",
                "target_formats": 3
            },
            {
                "sign_code": "YES",
                "gloss": "yes",
                "display_name": "Yes",
                "category": "response",
                "description": "Affirmative response",
                "instruction": "Make a fist and nod it up and down",
                "target_formats": 3
            },
            {
                "sign_code": "NO",
                "gloss": "no",
                "display_name": "No",
                "category": "response",
                "description": "Negative response",
                "instruction": "Tap thumb against extended fingers",
                "target_formats": 3
            },
            {
                "sign_code": "GOOD_MORNING",
                "gloss": "good_morning",
                "display_name": "Good Morning",
                "category": "greeting",
                "description": "Morning greeting",
                "instruction": "Combine 'good' and 'morning' signs sequentially",
                "target_formats": 3
            },
            {
                "sign_code": "GOODBYE",
                "gloss": "goodbye",
                "display_name": "Goodbye",
                "category": "greeting",
                "description": "Farewell greeting",
                "instruction": "Wave hand with palm facing inward",
                "target_formats": 3
            },
            {
                "sign_code": "HELP",
                "gloss": "help",
                "display_name": "Help",
                "category": "request",
                "description": "Request for assistance",
                "instruction": "Raise one flat hand with thumb up",
                "target_formats": 3
            },
            {
                "sign_code": "UNDERSTAND",
                "gloss": "understand",
                "display_name": "Understand",
                "category": "comprehension",
                "description": "Expression of understanding",
                "instruction": "Point to forehead with index finger",
                "target_formats": 3
            }
        ]
        
        created_signs = []
        for sign_data in approved_signs:
            # Check if sign already exists
            existing = self.sign_repo.get_sign_by_code(sign_data["sign_code"])
            if not existing:
                sign = self.sign_repo.create_sign(sign_data)
                created_signs.append(SignResponse.model_validate(sign))
            else:
                created_signs.append(SignResponse.model_validate(existing))
        
        return created_signs


