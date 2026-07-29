from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.associations import staff_roles
from app.models.role import Role
from app.models.rule import Rule
from app.models.staff import Staff
from app.schemas.bulk import BulkCreateResult, NameListCreate
from app.schemas.role import RoleCreate, RoleRead, RoleUpdate
from app.services.db_errors import conflict_on_duplicate_name


def _resolve_staff(db: Session, staff_ids: list[int]) -> list[Staff]:
    staff = list(db.scalars(select(Staff).where(Staff.id.in_(staff_ids)).order_by(Staff.name)))
    missing = set(staff_ids) - {s.id for s in staff}
    if missing:
        raise HTTPException(status_code=422, detail=f"Unknown staff_ids: {sorted(missing)}")
    return staff


def list_roles(db: Session) -> list[Role]:
    return list(db.scalars(select(Role).order_by(Role.name)))


def get_role(db: Session, role_id: int) -> Role:
    role = db.get(Role, role_id)
    if role is None:
        raise HTTPException(status_code=404, detail="Role not found")
    return role


def create_role(db: Session, data: RoleCreate) -> Role:
    role = Role(**data.model_dump())
    db.add(role)
    with conflict_on_duplicate_name(db, "Role"):
        db.commit()
    db.refresh(role)
    return role


def bulk_create_roles(db: Session, data: NameListCreate) -> BulkCreateResult[RoleRead]:
    """Role.name is UNIQUE — see bulk_create_tags for why already-existing names are reported
    as `skipped` rather than failing the whole batch."""
    # dict.fromkeys, not set(): collapses a name repeated within the paste (which would
    # otherwise violate the UNIQUE constraint against itself) while keeping pasted order.
    names = list(dict.fromkeys(data.names))
    existing = set(db.scalars(select(Role.name).where(Role.name.in_(names))))
    roles = [Role(name=name) for name in names if name not in existing]
    db.add_all(roles)
    # Still guarded: another client could insert one of these names between the SELECT above
    # and this commit.
    with conflict_on_duplicate_name(db, "Role"):
        db.commit()
    for role in roles:
        db.refresh(role)
    return BulkCreateResult(
        created=[RoleRead.model_validate(r) for r in roles],
        skipped=[name for name in names if name in existing],
    )


def update_role(db: Session, role_id: int, data: RoleUpdate) -> Role:
    role = get_role(db, role_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(role, field, value)
    with conflict_on_duplicate_name(db, "Role"):
        db.commit()
    db.refresh(role)
    return role


def apply_role_to_staff(db: Session, role_id: int, staff_ids: list[int]) -> list[Staff]:
    """Grant one Role to many Staff at once, additively.

    Deliberately unlike staff_service.update_staff, which replaces `staff.roles` wholesale
    when role_ids is supplied: bulk-applying must never strip Roles a Staff member already
    holds. Idempotent per Staff member — reapplying to someone who already holds the Role is
    a no-op for them, not an error — so the caller can re-Apply a persisted selection freely.
    Returns the affected Staff (ordered by name) so the client can refresh their Role chips.
    """
    role = get_role(db, role_id)  # 404s if missing
    staff = _resolve_staff(db, staff_ids)  # 422s listing any unknown ids
    for person in staff:
        if role not in person.roles:
            person.roles.append(role)
    db.commit()
    return staff


def delete_role(db: Session, role_id: int) -> None:
    role = get_role(db, role_id)
    in_use_by_staff = db.scalar(
        select(staff_roles.c.staff_id).where(staff_roles.c.role_id == role_id).limit(1)
    )
    in_use_by_rule = db.scalar(select(Rule.id).where(Rule.role_id == role_id).limit(1))
    if in_use_by_staff or in_use_by_rule:
        raise HTTPException(
            status_code=409,
            detail="Cannot delete a Role that is still held by Staff or referenced by Rules",
        )
    db.delete(role)
    db.commit()
