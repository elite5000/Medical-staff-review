from pydantic import BaseModel, ConfigDict, field_validator

from app.schemas.role import RoleRead
from app.schemas.unavailability import UnavailabilityRead


class PreferredDayInput(BaseModel):
    """week: 0 = week 1, 1 = week 2 of the fortnight. day_of_week: 0 = Monday ... 6 = Sunday."""

    week: int
    day_of_week: int


def _validate_preferred_days(days: list[PreferredDayInput]) -> list[PreferredDayInput]:
    if any(d.week not in (0, 1) for d in days):
        raise ValueError("week must be 0 (week 1) or 1 (week 2)")
    if any(d.day_of_week < 0 or d.day_of_week > 6 for d in days):
        raise ValueError("day_of_week must be between 0 (Monday) and 6 (Sunday)")
    keys = [(d.week, d.day_of_week) for d in days]
    if len(set(keys)) != len(keys):
        raise ValueError("preferred_days must not contain duplicates")
    return days


class StaffCreate(BaseModel):
    name: str
    active: bool = True
    role_ids: list[int] = []
    preferred_days: list[PreferredDayInput] = []

    _validate_days = field_validator("preferred_days")(_validate_preferred_days)


class StaffUpdate(BaseModel):
    name: str | None = None
    active: bool | None = None
    role_ids: list[int] | None = None
    preferred_days: list[PreferredDayInput] | None = None

    @field_validator("preferred_days")
    @classmethod
    def _validate_days(cls, days: list[PreferredDayInput] | None) -> list[PreferredDayInput] | None:
        return None if days is None else _validate_preferred_days(days)


class StaffRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    active: bool
    roles: list[RoleRead]
    preferred_days: list[PreferredDayInput]
    unavailabilities: list[UnavailabilityRead]
