"""Translates DB-level constraint violations into the HTTPExceptions callers already use
for other 409s, instead of letting FastAPI's default handler turn an IntegrityError into an
unhelpful 500."""

from collections.abc import Generator
from contextlib import contextmanager

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session


@contextmanager
def conflict_on_duplicate_name(db: Session, entity_name: str) -> Generator[None]:
    try:
        yield
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409, detail=f"A {entity_name} with this name already exists"
        ) from None
