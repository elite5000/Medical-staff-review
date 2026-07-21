from pydantic import BaseModel, ConfigDict


class SettingsUpdate(BaseModel):
    shift_length_minutes: int | None = None
    travel_time_minutes: int | None = None
    max_daily_minutes: int | None = None


class SettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    shift_length_minutes: int
    travel_time_minutes: int
    max_daily_minutes: int
