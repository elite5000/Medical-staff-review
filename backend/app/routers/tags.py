from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.tag import TagCreate, TagRead, TagUpdate
from app.services import tag_service

router = APIRouter(prefix="/tags", tags=["tags"])


@router.get("", response_model=list[TagRead])
def list_tags(db: Session = Depends(get_db)) -> list[TagRead]:
    return [TagRead.model_validate(t) for t in tag_service.list_tags(db)]


@router.post("", response_model=TagRead, status_code=201)
def create_tag(data: TagCreate, db: Session = Depends(get_db)) -> TagRead:
    return TagRead.model_validate(tag_service.create_tag(db, data))


@router.get("/{tag_id}", response_model=TagRead)
def get_tag(tag_id: int, db: Session = Depends(get_db)) -> TagRead:
    return TagRead.model_validate(tag_service.get_tag(db, tag_id))


@router.patch("/{tag_id}", response_model=TagRead)
def update_tag(tag_id: int, data: TagUpdate, db: Session = Depends(get_db)) -> TagRead:
    return TagRead.model_validate(tag_service.update_tag(db, tag_id, data))


@router.delete("/{tag_id}", status_code=204)
def delete_tag(tag_id: int, db: Session = Depends(get_db)) -> None:
    tag_service.delete_tag(db, tag_id)
