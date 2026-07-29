from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.associations import room_tags
from app.models.room import Room
from app.models.rule import Rule
from app.models.tag import Tag
from app.schemas.bulk import BulkCreateResult, NameListCreate
from app.schemas.tag import TagCreate, TagRead, TagUpdate
from app.services.db_errors import conflict_on_duplicate_name


def _resolve_rooms(db: Session, room_ids: list[int]) -> list[Room]:
    rooms = list(db.scalars(select(Room).where(Room.id.in_(room_ids)).order_by(Room.name)))
    missing = set(room_ids) - {r.id for r in rooms}
    if missing:
        raise HTTPException(status_code=422, detail=f"Unknown room_ids: {sorted(missing)}")
    return rooms


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
    with conflict_on_duplicate_name(db, "Tag"):
        db.commit()
    db.refresh(tag)
    return tag


def bulk_create_tags(db: Session, data: NameListCreate) -> BulkCreateResult[TagRead]:
    """Tag.name is UNIQUE, so a batch pasted from a spreadsheet will routinely repeat names
    the practice already has. Rather than 409ing the whole batch, those are reported back as
    `skipped` and the rest are created."""
    # dict.fromkeys, not set(): a name repeated *within* the paste must collapse to one Tag
    # (otherwise the batch would violate the UNIQUE constraint against itself) while keeping
    # the pasted order, which is the order `created`/`skipped` are reported in.
    names = list(dict.fromkeys(data.names))
    existing = set(db.scalars(select(Tag.name).where(Tag.name.in_(names))))
    tags = [Tag(name=name) for name in names if name not in existing]
    db.add_all(tags)
    # Still guarded: another client could insert one of these names between the SELECT above
    # and this commit.
    with conflict_on_duplicate_name(db, "Tag"):
        db.commit()
    for tag in tags:
        db.refresh(tag)
    return BulkCreateResult(
        created=[TagRead.model_validate(t) for t in tags],
        skipped=[name for name in names if name in existing],
    )


def update_tag(db: Session, tag_id: int, data: TagUpdate) -> Tag:
    tag = get_tag(db, tag_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tag, field, value)
    with conflict_on_duplicate_name(db, "Tag"):
        db.commit()
    db.refresh(tag)
    return tag


def apply_tag_to_rooms(db: Session, tag_id: int, room_ids: list[int]) -> list[Room]:
    """Attach one Tag to many Rooms in a single transaction.

    Deliberately ADDITIVE, unlike room_service.update_room, which full-replaces room.tags
    when tag_ids is supplied: this unions the Tag into each Room's existing tags and never
    detaches anything. Re-applying to a Room that already carries the Tag is a silent no-op
    for that Room (not an error), so the whole call is idempotent — and duplicate ids in
    room_ids collapse via the IN() lookup.
    """
    tag = get_tag(db, tag_id)  # 404s if the Tag doesn't exist
    rooms = _resolve_rooms(db, room_ids)  # 422s listing any unknown room_ids
    for room in rooms:
        if tag not in room.tags:
            room.tags.append(tag)
    db.commit()
    for room in rooms:
        db.refresh(room)
    return rooms


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
