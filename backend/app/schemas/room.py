from pydantic import BaseModel, ConfigDict

from app.schemas.bulk import NameListCreate
from app.schemas.tag import TagRead


class RoomBase(BaseModel):
    name: str
    building_id: int


class RoomCreate(RoomBase):
    tag_ids: list[int] = []


class RoomBulkCreate(NameListCreate):
    """Unlike the name-only bulk creates, every Room needs a Building, so the whole batch is
    created under one — the client picks it once, above the names textarea."""

    building_id: int


class RoomUpdate(BaseModel):
    name: str | None = None
    building_id: int | None = None
    tag_ids: list[int] | None = None


class RoomRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    building_id: int
    tags: list[TagRead]
