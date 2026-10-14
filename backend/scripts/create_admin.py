"""Create the first SignBridge administrator from a trusted local shell."""

import argparse
from getpass import getpass

from app.core.database import SessionLocal
from app.models.user import User
from app.repositories.user_repository import UserRepository


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, help="Administrator's name")
    parser.add_argument("--email", required=True, help="Administrator's email")
    args = parser.parse_args()

    password = getpass("Administrator password (minimum 12 characters): ")
    if len(password) < 12:
        raise SystemExit("Password must contain at least 12 characters.")
    confirmation = getpass("Confirm password: ")
    if password != confirmation:
        raise SystemExit("Passwords do not match.")

    db = SessionLocal()
    try:
        existing_admin = db.query(User).filter(User.role == "admin").first()
        if existing_admin:
            raise SystemExit("An administrator already exists; no account was created.")
        if db.query(User).filter(User.email == args.email.lower()).first():
            raise SystemExit("That email already belongs to an account; no account was created.")

        user = UserRepository(db).create_user(
            name=args.name.strip(),
            email=args.email,
            password=password,
            role="admin",
        )
        print(f"Administrator account created: {user.email}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
