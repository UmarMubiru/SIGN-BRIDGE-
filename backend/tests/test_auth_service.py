from datetime import timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from app.core.config import settings
from app.core.auth_dependencies import get_current_user
from app.core.security import decode_token
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService


@pytest.fixture
def auth_service(monkeypatch):
    monkeypatch.setattr(settings, "SECRET_KEY", "test-secret-key-with-more-than-32-characters")
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    User.__table__.create(engine)
    session = Session(engine)
    service = AuthService(UserRepository(session))
    try:
        yield service
    finally:
        session.close()
        engine.dispose()


def test_registration_and_login_issue_typed_versioned_tokens(auth_service):
    registered = auth_service.register_user(
        name="Local Collector",
        email="Collector@Example.org",
        password="long-test-password",
    )

    assert registered.role == "collector"
    user = auth_service.user_repo.get_user_by_email("collector@example.org")
    assert user.password_hash != "long-test-password"

    token = auth_service.login_user("collector@example.org", "long-test-password")
    access = decode_token(token.access_token)
    refresh = decode_token(token.refresh_token)
    assert access["type"] == "access"
    assert refresh["type"] == "refresh"
    assert access["ver"] == refresh["ver"] == 0
    assert auth_service.get_current_user(user.public_id, access["ver"]) is not None


def test_duplicate_registration_and_incorrect_password_are_rejected(auth_service):
    auth_service.register_user(
        name="Local Collector",
        email="collector@example.org",
        password="long-test-password",
    )

    with pytest.raises(ValueError, match="already exists"):
        auth_service.register_user(
            name="Another Collector",
            email="COLLECTOR@example.org",
            password="another-test-password",
        )
    with pytest.raises(ValueError, match="Invalid email or password"):
        auth_service.login_user("collector@example.org", "incorrect-password")


def test_inactive_account_cannot_login_or_use_existing_token(auth_service):
    auth_service.register_user(
        name="Local Collector",
        email="collector@example.org",
        password="long-test-password",
    )
    token = auth_service.login_user("collector@example.org", "long-test-password")
    user = auth_service.user_repo.get_user_by_email("collector@example.org")
    user.is_active = False
    auth_service.user_repo.db.commit()

    with pytest.raises(ValueError, match="Invalid email or password"):
        auth_service.login_user("collector@example.org", "long-test-password")
    assert auth_service.get_current_user(user.public_id, 0) is None
    with pytest.raises(ValueError, match="User not found or inactive"):
        auth_service.refresh_tokens(token.refresh_token)


def test_public_registration_cannot_set_admin_role(monkeypatch):
    from types import SimpleNamespace
    from app.api.v1 import auth as auth_routes
    from app.schemas.user import UserCreate

    captured = {}

    class FakeService:
        def __init__(self, _repository):
            pass

        def register_user(self, **kwargs):
            captured.update(kwargs)
            return SimpleNamespace(role=kwargs["role"])

    monkeypatch.setattr(auth_routes, "UserRepository", lambda _db: object())
    monkeypatch.setattr(auth_routes, "AuthService", FakeService)
    request = UserCreate.model_validate({
        "name": "Public Admin Attempt",
        "email": "attempt@example.org",
        "password": "long-test-password",
        "role": "admin",
    })

    result = auth_routes.register(request, db=object())
    assert result.role == "collector"
    assert captured["role"] == "collector"


def test_refresh_token_cannot_authenticate_and_logout_revokes_tokens(auth_service):
    auth_service.register_user(
        name="Local Collector",
        email="collector@example.org",
        password="long-test-password",
    )
    user = auth_service.user_repo.get_user_by_email("collector@example.org")
    token = auth_service.login_user("collector@example.org", "long-test-password")
    access = decode_token(token.access_token)

    assert auth_service.get_current_user(user.public_id, 0) is not None
    with pytest.raises(ValueError, match="Invalid refresh token"):
        auth_service.refresh_tokens(token.access_token)

    assert auth_service.logout_user(user.public_id)
    assert auth_service.get_current_user(user.public_id, access["ver"]) is None
    with pytest.raises(ValueError, match="User not found or inactive"):
        auth_service.refresh_tokens(token.refresh_token)

    renewed = auth_service.login_user("collector@example.org", "long-test-password")
    assert decode_token(renewed.access_token)["ver"] == 1


def test_refresh_rejects_wrong_token_version(auth_service):
    auth_service.register_user(
        name="Local Collector",
        email="collector@example.org",
        password="long-test-password",
    )
    token = auth_service.login_user("collector@example.org", "long-test-password")
    user = auth_service.user_repo.get_user_by_email("collector@example.org")
    user.token_version = 5
    auth_service.user_repo.db.commit()

    with pytest.raises(ValueError, match="User not found or inactive"):
        auth_service.refresh_tokens(token.refresh_token)


def test_expired_tokens_are_rejected(auth_service):
    from app.core.security import create_access_token

    token = create_access_token(
        {"sub": "USR-TEST", "ver": 0}, expires_delta=timedelta(seconds=-1)
    )
    assert decode_token(token) is None


def test_auth_dependency_rejects_refresh_tokens(auth_service):
    from fastapi import HTTPException
    from fastapi.security import HTTPAuthorizationCredentials

    auth_service.register_user(
        name="Local Collector",
        email="collector@example.org",
        password="long-test-password",
    )
    token = auth_service.login_user("collector@example.org", "long-test-password")
    db = auth_service.user_repo.db

    access_user = get_current_user(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials=token.access_token),
        db,
    )
    assert access_user.role == "collector"
    with pytest.raises(HTTPException) as error:
        get_current_user(
            HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=token.refresh_token
            ),
            db,
        )
    assert error.value.status_code == 401
