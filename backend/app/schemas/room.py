from pydantic import BaseModel, ConfigDict

from app.schemas.tag import TagRead


class RoomBase(BaseModel):
    name: str
    building_id: int


class RoomCreate(RoomBase):
    tag_ids: list[int] = []


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
