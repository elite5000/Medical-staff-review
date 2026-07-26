from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.building import Building
from app.models.room import Room
from app.models.rule import Rule
from app.schemas.building import BuildingCreate, BuildingUpdate
from app.services.db_errors import conflict_on_duplicate_name


def list_buildings(db: Session) -> list[Building]:
    return list(db.scalars(select(Building).order_by(Building.name)))


def get_building(db: Session, building_id: int) -> Building:
    building = db.get(Building, building_id)
    if building is None:
        raise HTTPException(status_code=404, detail="Building not found")
    return building


def create_building(db: Session, data: BuildingCreate) -> Building:
    building = Building(**data.model_dump())
    db.add(building)
    with conflict_on_duplicate_name(db, "Building"):
        db.commit()
    db.refresh(building)
    return building


def update_building(db: Session, building_id: int, data: BuildingUpdate) -> Building:
    building = get_building(db, building_id)
    updates = data.model_dump(exclude_unset=True)
    opening_minutes = updates.get("opening_minutes", building.opening_minutes)
    closing_minutes = updates.get("closing_minutes", building.closing_minutes)
    if closing_minutes <= opening_minutes:
        raise HTTPException(status_code=422, detail="closing_minutes must be after opening_minutes")
    for field, value in updates.items():
        setattr(building, field, value)
    with conflict_on_duplicate_name(db, "Building"):
        db.commit()
    db.refresh(building)
    return building


def delete_building(db: Session, building_id: int) -> None:
    building = get_building(db, building_id)
    # Never cascade — a Building with Rooms or Rules attached would leave
    # dangling references in permanent Roster history if deleted outright.
    has_rooms = db.scalar(select(Room.id).where(Room.building_id == building_id).limit(1))
    has_rules = db.scalar(select(Rule.id).where(Rule.building_id == building_id).limit(1))
    if has_rooms or has_rules:
        raise HTTPException(
            status_code=409,
            detail="Cannot delete a Building that still has Rooms or Rules attached",
        )
    db.delete(building)
    db.commit()
