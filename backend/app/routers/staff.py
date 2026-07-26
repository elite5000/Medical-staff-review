from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.staff import StaffCreate, StaffRead, StaffUpdate
from app.schemas.unavailability import UnavailabilityCreate, UnavailabilityRead
from app.services import staff_service

router = APIRouter(prefix="/staff", tags=["staff"])


@router.get("", response_model=list[StaffRead])
def list_staff(db: Session = Depends(get_db)) -> list[StaffRead]:
    return [staff_service.staff_to_read(s) for s in staff_service.list_staff(db)]


@router.post("", response_model=StaffRead, status_code=201)
def create_staff(data: StaffCreate, db: Session = Depends(get_db)) -> StaffRead:
    return staff_service.staff_to_read(staff_service.create_staff(db, data))


@router.get("/{staff_id}", response_model=StaffRead)
def get_staff(staff_id: int, db: Session = Depends(get_db)) -> StaffRead:
    return staff_service.staff_to_read(staff_service.get_staff(db, staff_id))


@router.patch("/{staff_id}", response_model=StaffRead)
def update_staff(staff_id: int, data: StaffUpdate, db: Session = Depends(get_db)) -> StaffRead:
    return staff_service.staff_to_read(staff_service.update_staff(db, staff_id, data))


@router.delete("/{staff_id}", status_code=204)
def delete_staff(staff_id: int, db: Session = Depends(get_db)) -> None:
    staff_service.delete_staff(db, staff_id)


@router.post(
    "/{staff_id}/unavailabilities",
    response_model=UnavailabilityRead,
    status_code=201,
)
def add_unavailability(
    staff_id: int, data: UnavailabilityCreate, db: Session = Depends(get_db)
) -> UnavailabilityRead:
    return UnavailabilityRead.model_validate(staff_service.add_unavailability(db, staff_id, data))


@router.delete("/{staff_id}/unavailabilities/{unavailability_id}", status_code=204)
def remove_unavailability(
    staff_id: int, unavailability_id: int, db: Session = Depends(get_db)
) -> None:
    staff_service.remove_unavailability(db, staff_id, unavailability_id)
