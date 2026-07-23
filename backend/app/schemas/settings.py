from pydantic import BaseModel, ConfigDict, Field


class SettingsUpdate(BaseModel):
    # gt=0: a zero or negative shift length/max-daily-minutes divides by zero or makes no
    # sense when the solver turns them into block counts; travel time may legitimately be 0.
    shift_length_minutes: int | None = Field(default=None, gt=0)
    travel_time_minutes: int | None = Field(default=None, ge=0)
    max_daily_minutes: int | None = Field(default=None, gt=0)


class SettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    shift_length_minutes: int
    travel_time_minutes: int
    max_daily_minutes: int
