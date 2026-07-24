from pydantic import BaseModel, ConfigDict, Field, model_validator

# Shifts are only ever compared for conflicts within the same calendar `date` (see
# app/services/solver/model.py and roster_service.set_shift_staff), so opening/closing
# minutes must stay within one day — a window that spills past midnight (e.g. closing_minutes
# > 1440) would have its overnight portion silently exempt from that same-day conflict check.
_MINUTES_PER_DAY = 24 * 60


class BuildingBase(BaseModel):
    name: str
    opening_minutes: int = Field(ge=0, le=_MINUTES_PER_DAY)
    closing_minutes: int = Field(ge=0, le=_MINUTES_PER_DAY)

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
    opening_minutes: int | None = Field(default=None, ge=0, le=_MINUTES_PER_DAY)
    closing_minutes: int | None = Field(default=None, ge=0, le=_MINUTES_PER_DAY)


class BuildingRead(BuildingBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
