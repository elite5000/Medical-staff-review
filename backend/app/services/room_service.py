from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.roster import RosterViolation
from app.models.shift import Shift
from app.models.tag import Tag
from app.schemas.bulk import BulkCreateResult
from app.schemas.room import RoomBulkCreate, RoomCreate, RoomRead, RoomUpdate
from app.services.building_service import get_building


def _resolve_tags(db: Session, tag_ids: list[int]) -> list[Tag]:
    tags = list(db.scalars(select(Tag).where(Tag.id.in_(tag_ids))))
    missing = set(tag_ids) - {t.id for t in tags}
    if missing:
        raise HTTPException(status_code=422, detail=f"Unknown tag_ids: {sorted(missing)}")
    return tags


def list_rooms(db: Session) -> list[Room]:
    return list(db.scalars(select(Room).order_by(Room.name)))


def get_room(db: Session, room_id: int) -> Room:
    room = db.get(Room, room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def create_room(db: Session, data: RoomCreate) -> Room:
    get_building(db, data.building_id)  # 404s if the building doesn't exist
    room = Room(
        name=data.name,
        building_id=data.building_id,
        tags=_resolve_tags(db, data.tag_ids),
    )
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def bulk_create_rooms(db: Session, data: RoomBulkCreate) -> BulkCreateResult[RoomRead]:
    """Room.name has no UNIQUE constraint (rooms in different Buildings routinely share a
    name), so nothing is deduped or skipped here — every non-blank line becomes a Room."""
    get_building(db, data.building_id)  # 404s if the building doesn't exist
    rooms = [Room(name=name, building_id=data.building_id, tags=[]) for name in data.names]
    db.add_all(rooms)
    db.commit()
    for room in rooms:
        db.refresh(room)
    return BulkCreateResult(created=[RoomRead.model_validate(r) for r in rooms])


def _has_roster_history(db: Session, room_id: int) -> bool:
    has_shifts = db.scalar(select(Shift.id).where(Shift.room_id == room_id).limit(1))
    has_violations = db.scalar(
        select(RosterViolation.id).where(RosterViolation.room_id == room_id).limit(1)
    )
    return bool(has_shifts or has_violations)


def update_room(db: Session, room_id: int, data: RoomUpdate) -> Room:
    room = get_room(db, room_id)
    updates = data.model_dump(exclude_unset=True, exclude={"tag_ids"})
    if data.building_id is not None:
        get_building(db, data.building_id)
        # Retained Shift/RosterViolation rows only store room_id and shift_index; wall-clock
        # timing for them is derived from the Room's *current* Building (see
        # roster_service.set_shift_staff), so moving a Room with roster history to a
        # different Building would reinterpret that history under the wrong hours.
        if data.building_id != room.building_id and _has_roster_history(db, room_id):
            raise HTTPException(
                status_code=409,
                detail="Cannot move a Room to a different Building once it appears in a "
                "generated Roster",
            )
    for field, value in updates.items():
        setattr(room, field, value)
    if data.tag_ids is not None:
        room.tags = _resolve_tags(db, data.tag_ids)
    db.commit()
    db.refresh(room)
    return room


def delete_room(db: Session, room_id: int) -> None:
    room = get_room(db, room_id)
    # A Room that already appears in a generated Roster's Shifts, or that a generated
    # Roster's violation history points at (e.g. a room that went unfilled), must not
    # vanish from history.
    if _has_roster_history(db, room_id):
        raise HTTPException(
            status_code=409,
            detail="Cannot delete a Room that appears in a generated Roster",
        )
    db.delete(room)
    db.commit()
