from datetime import date

from pydantic import BaseModel, ConfigDict, model_validator


class UnavailabilityCreate(BaseModel):
    start_date: date
    end_date: date
    reason: str | None = None

    @model_validator(mode="after")
    def check_date_order(self) -> "UnavailabilityCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date must not be before start_date")
        return self


class UnavailabilityRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    staff_id: int
    start_date: date
    end_date: date
    reason: str | None
