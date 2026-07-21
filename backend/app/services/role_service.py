from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.associations import staff_roles
from app.models.role import Role
from app.models.rule import Rule
from app.schemas.role import RoleCreate, RoleUpdate


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
    db.commit()
    db.refresh(role)
    return role


def update_role(db: Session, role_id: int, data: RoleUpdate) -> Role:
    role = get_role(db, role_id)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(role, field, value)
    db.commit()
    db.refresh(role)
    return role


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
