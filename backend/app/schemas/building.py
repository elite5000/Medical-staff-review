from pydantic import BaseModel, ConfigDict


class BuildingBase(BaseModel):
    name: str
    opening_minutes: int
    closing_minutes: int


class BuildingCreate(BuildingBase):
    pass


class BuildingUpdate(BaseModel):
    name: str | None = None
    opening_minutes: int | None = None
    closing_minutes: int | None = None


class BuildingRead(BuildingBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
