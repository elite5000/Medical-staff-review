from pydantic import BaseModel, ConfigDict, model_validator


class BuildingBase(BaseModel):
    name: str
    opening_minutes: int
    closing_minutes: int

    @model_validator(mode="after")
    def _check_hour_order(self) -> "BuildingBase":
        # closing_minutes <= opening_minutes makes _blocks_per_day return 0, silently
        # excluding every Room in the Building from the roster with no violation raised.
        if self.closing_minutes <= self.opening_minutes:
            raise ValueError("closing_minutes must be after opening_minutes")
        return self


class BuildingCreate(BuildingBase):
    pass


class BuildingUpdate(BaseModel):
    name: str | None = None
    opening_minutes: int | None = None
    closing_minutes: int | None = None


class BuildingRead(BuildingBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
