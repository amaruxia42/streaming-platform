from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from collections.abc import Generator
from app.core.config import settings


engine = create_engine(
    settings.database_uri,
)

SessionLocal = sessionmaker(
    bind=engine,
)


def get_db() -> Generator[Session, None, None]:
    session = SessionLocal()

    try:
        yield session
    finally:
        session.close()