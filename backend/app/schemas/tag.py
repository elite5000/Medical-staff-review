from pydantic import BaseModel, ConfigDict


class TagBase(BaseModel):
    name: str


class TagCreate(TagBase):
    pass


class TagUpdate(BaseModel):
    name: str | None = None


class TagRead(TagBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class TagApplyToRooms(BaseModel):
    """Body of POST /tags/{tag_id}/apply-to-rooms. Duplicate ids are harmless — the tag is
    unioned into each room's existing tags, so applying twice is a no-op."""

    room_ids: list[int]
