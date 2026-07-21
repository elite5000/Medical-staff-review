from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.associations import room_tags
from app.models.rule import Rule
from app.models.tag import Tag
from app.schemas.tag import TagCreate, TagUpdate


def list_tags(db: Session) -> list[Tag]:
    return list(db.scalars(select(Tag).order_by(Tag.name)))


def get_tag(db: Session, tag_id: int) -> Tag:
    tag = db.get(Tag, tag_id)
    if tag is None:
        raise HTTPException(status_code=404, detail="Tag not found")
    return tag


def create_tag(db: Session, data: TagCreate) -> Tag:
    tag = Tag(**data.model_dump())
    db.add(tag)
    db.commit()
    db.refresh(tag)
    return tag


def update_tag(db: Session, tag_id: int, data: TagUpdate) -> Tag:
    tag = get_tag(db, tag_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tag, field, value)
    db.commit()
    db.refresh(tag)
    return tag


def delete_tag(db: Session, tag_id: int) -> None:
    tag = get_tag(db, tag_id)
    in_use_by_room = db.scalar(
        select(room_tags.c.room_id).where(room_tags.c.tag_id == tag_id).limit(1)
    )
    in_use_by_rule = db.scalar(select(Rule.id).where(Rule.tag_id == tag_id).limit(1))
    if in_use_by_room or in_use_by_rule:
        raise HTTPException(
            status_code=409,
            detail="Cannot delete a Tag that is still attached to Rooms or referenced by Rules",
        )
    db.delete(tag)
    db.commit()
