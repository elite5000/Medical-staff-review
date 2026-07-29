from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.bulk import BulkCreateResult
from app.schemas.room import RoomBulkCreate, RoomCreate, RoomRead, RoomUpdate
from app.services import room_service

router = APIRouter(prefix="/rooms", tags=["rooms"])


@router.get("", response_model=list[RoomRead])
def list_rooms(db: Session = Depends(get_db)) -> list[RoomRead]:
    return [RoomRead.model_validate(r) for r in room_service.list_rooms(db)]


@router.post("", response_model=RoomRead, status_code=201)
def create_room(data: RoomCreate, db: Session = Depends(get_db)) -> RoomRead:
    return RoomRead.model_validate(room_service.create_room(db, data))


# Declared before the /{room_id} routes so "bulk" is never parsed as a room id.
@router.post("/bulk", response_model=BulkCreateResult[RoomRead], status_code=201)
def bulk_create_rooms(
    data: RoomBulkCreate, db: Session = Depends(get_db)
) -> BulkCreateResult[RoomRead]:
    return room_service.bulk_create_rooms(db, data)


@router.get("/{room_id}", response_model=RoomRead)
def get_room(room_id: int, db: Session = Depends(get_db)) -> RoomRead:
    return RoomRead.model_validate(room_service.get_room(db, room_id))


@router.patch("/{room_id}", response_model=RoomRead)
def update_room(room_id: int, data: RoomUpdate, db: Session = Depends(get_db)) -> RoomRead:
    return RoomRead.model_validate(room_service.update_room(db, room_id, data))


@router.delete("/{room_id}", status_code=204)
def delete_room(room_id: int, db: Session = Depends(get_db)) -> None:
    room_service.delete_room(db, room_id)
