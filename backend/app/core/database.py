from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

connect_args = (
    {"check_same_thread": False}
    if settings.DATABASE_URL.startswith("sqlite")
    else {}
)
engine_options = {
    "connect_args": connect_args,
    "pool_pre_ping": True,
}
if not settings.DATABASE_URL.startswith("sqlite"):
    # The web client (including the compact phone layout) refreshes several
    # views while background video processing and ZIP exports also use the DB.
    # Allow those short requests to proceed without exhausting SQLAlchemy's
    # very small default pool when more than one client is open.
    engine_options.update(
        pool_size=10,
        max_overflow=10,
        pool_timeout=30,
        pool_recycle=1800,
    )
engine = create_engine(settings.DATABASE_URL, **engine_options)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
