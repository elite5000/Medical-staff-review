from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.roster import (
    RosterDetailRead,
    RosterGenerateRequest,
    RosterRead,
    ShiftRead,
    ShiftUpdateRequest,
)
from app.services import roster_service

router = APIRouter(prefix="/rosters", tags=["rosters"])


@router.get("", response_model=list[RosterRead])
def list_rosters(db: Session = Depends(get_db)) -> list[RosterRead]:
    return [RosterRead.model_validate(r) for r in roster_service.list_rosters(db)]


@router.post("", response_model=RosterRead, status_code=201)
def generate_roster(data: RosterGenerateRequest, db: Session = Depends(get_db)) -> RosterRead:
    roster = roster_service.generate_roster(db, data.start_date, data.num_days)
    return RosterRead.model_validate(roster)


@router.get("/{roster_id}", response_model=RosterDetailRead)
def get_roster(roster_id: int, db: Session = Depends(get_db)) -> RosterDetailRead:
    return RosterDetailRead.model_validate(roster_service.get_roster(db, roster_id))


@router.post("/{roster_id}/regenerate", response_model=RosterRead, status_code=201)
def regenerate_roster(roster_id: int, db: Session = Depends(get_db)) -> RosterRead:
    roster = roster_service.regenerate_roster(db, roster_id)
    return RosterRead.model_validate(roster)


@router.patch("/{roster_id}/shifts/{shift_id}", response_model=ShiftRead)
def update_shift(
    roster_id: int, shift_id: int, data: ShiftUpdateRequest, db: Session = Depends(get_db)
) -> ShiftRead:
    shift = roster_service.set_shift_staff(db, roster_id, shift_id, data.staff_id)
    return ShiftRead.model_validate(shift)
