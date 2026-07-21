from pydantic import BaseModel, ConfigDict, field_validator

from app.schemas.role import RoleRead
from app.schemas.unavailability import UnavailabilityRead


def _validate_preferred_days(days: list[int]) -> list[int]:
    if any(d < 0 or d > 6 for d in days):
        raise ValueError("day_of_week must be between 0 (Monday) and 6 (Sunday)")
    if len(set(days)) != len(days):
        raise ValueError("preferred_days must not contain duplicates")
    return days


class StaffCreate(BaseModel):
    name: str
    active: bool = True
    role_ids: list[int] = []
    preferred_days: list[int] = []

    _validate_days = field_validator("preferred_days")(_validate_preferred_days)


class StaffUpdate(BaseModel):
    name: str | None = None
    active: bool | None = None
    role_ids: list[int] | None = None
    preferred_days: list[int] | None = None

    @field_validator("preferred_days")
    @classmethod
    def _validate_days(cls, days: list[int] | None) -> list[int] | None:
        return None if days is None else _validate_preferred_days(days)


class StaffRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    active: bool
    roles: list[RoleRead]
    preferred_days: list[int]
    unavailabilities: list[UnavailabilityRead]
