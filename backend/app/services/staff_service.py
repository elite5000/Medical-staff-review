from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.role import Role
from app.models.shift import Shift
from app.models.staff import PreferredDay, Staff, Unavailability
from app.schemas.bulk import BulkCreateResult, NameListCreate
from app.schemas.role import RoleRead
from app.schemas.staff import PreferredDayInput, StaffCreate, StaffRead, StaffUpdate
from app.schemas.unavailability import UnavailabilityCreate, UnavailabilityRead


def staff_to_read(staff: Staff) -> StaffRead:
    # Built explicitly rather than via from_attributes: preferred_days on the ORM model is
    # a list of PreferredDay rows, but the API represents it as a list of {week, day_of_week}.
    return StaffRead(
        id=staff.id,
        name=staff.name,
        active=staff.active,
        roles=[RoleRead.model_validate(r) for r in staff.roles],
        preferred_days=sorted(
            (
                PreferredDayInput(week=pd.week, day_of_week=pd.day_of_week)
                for pd in staff.preferred_days
            ),
            key=lambda p: (p.week, p.day_of_week),
        ),
        unavailabilities=[UnavailabilityRead.model_validate(u) for u in staff.unavailabilities],
    )


def _resolve_roles(db: Session, role_ids: list[int]) -> list[Role]:
    roles = list(db.scalars(select(Role).where(Role.id.in_(role_ids))))
    missing = set(role_ids) - {r.id for r in roles}
    if missing:
        raise HTTPException(status_code=422, detail=f"Unknown role_ids: {sorted(missing)}")
    return roles


def list_staff(db: Session) -> list[Staff]:
    return list(db.scalars(select(Staff).order_by(Staff.name)))


def get_staff(db: Session, staff_id: int) -> Staff:
    staff = db.get(Staff, staff_id)
    if staff is None:
        raise HTTPException(status_code=404, detail="Staff not found")
    return staff


def create_staff(db: Session, data: StaffCreate) -> Staff:
    staff = Staff(
        name=data.name,
        active=data.active,
        roles=_resolve_roles(db, data.role_ids),
        preferred_days=[
            PreferredDay(week=p.week, day_of_week=p.day_of_week) for p in data.preferred_days
        ],
    )
    db.add(staff)
    db.commit()
    db.refresh(staff)
    return staff


def bulk_create_staff(db: Session, data: NameListCreate) -> BulkCreateResult[StaffRead]:
    """Staff.name has no UNIQUE constraint (two people can share a name), so nothing is
    deduped or skipped. Roles and preferred days aren't settable in bulk — the batch is
    names only, and each new member is edited individually afterwards."""
    staff = [Staff(name=name, active=True, roles=[], preferred_days=[]) for name in data.names]
    db.add_all(staff)
    db.commit()
    for member in staff:
        db.refresh(member)
    return BulkCreateResult(created=[staff_to_read(s) for s in staff])


def update_staff(db: Session, staff_id: int, data: StaffUpdate) -> Staff:
    staff = get_staff(db, staff_id)
    updates = data.model_dump(exclude_unset=True, exclude={"role_ids", "preferred_days"})
    for field, value in updates.items():
        setattr(staff, field, value)
    if data.role_ids is not None:
        staff.roles = _resolve_roles(db, data.role_ids)
    if data.preferred_days is not None:
        # Flushed separately so the deletes land before the inserts below — otherwise a day
        # unchanged between old and new collides with itself under the
        # (staff_id, week, day_of_week) UNIQUE constraint, since SQLAlchemy doesn't guarantee
        # delete-before-insert ordering for a wholesale collection replacement.
        staff.preferred_days.clear()
        db.flush()
        staff.preferred_days = [
            PreferredDay(week=p.week, day_of_week=p.day_of_week) for p in data.preferred_days
        ]
    db.commit()
    db.refresh(staff)
    return staff


def delete_staff(db: Session, staff_id: int) -> None:
    staff = get_staff(db, staff_id)
    has_shifts = db.scalar(select(Shift.id).where(Shift.staff_id == staff_id).limit(1))
    if has_shifts:
        raise HTTPException(
            status_code=409,
            detail="Cannot delete Staff who appear in a generated Roster — deactivate instead",
        )
    db.delete(staff)  # cascades PreferredDay/Unavailability rows (see Staff relationships)
    db.commit()


def add_unavailability(db: Session, staff_id: int, data: UnavailabilityCreate) -> Unavailability:
    get_staff(db, staff_id)  # 404s if missing
    unavailability = Unavailability(staff_id=staff_id, **data.model_dump())
    db.add(unavailability)
    db.commit()
    db.refresh(unavailability)
    return unavailability


def remove_unavailability(db: Session, staff_id: int, unavailability_id: int) -> None:
    unavailability = db.get(Unavailability, unavailability_id)
    if unavailability is None or unavailability.staff_id != staff_id:
        raise HTTPException(status_code=404, detail="Unavailability not found")
    db.delete(unavailability)
    db.commit()
