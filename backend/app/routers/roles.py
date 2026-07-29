from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.bulk import BulkCreateResult, NameListCreate
from app.schemas.role import RoleCreate, RoleRead, RoleUpdate
from app.services import role_service

router = APIRouter(prefix="/roles", tags=["roles"])


@router.get("", response_model=list[RoleRead])
def list_roles(db: Session = Depends(get_db)) -> list[RoleRead]:
    return [RoleRead.model_validate(r) for r in role_service.list_roles(db)]


@router.post("", response_model=RoleRead, status_code=201)
def create_role(data: RoleCreate, db: Session = Depends(get_db)) -> RoleRead:
    return RoleRead.model_validate(role_service.create_role(db, data))


# Declared before the /{role_id} routes so "bulk" is never parsed as a role id.
@router.post("/bulk", response_model=BulkCreateResult[RoleRead], status_code=201)
def bulk_create_roles(
    data: NameListCreate, db: Session = Depends(get_db)
) -> BulkCreateResult[RoleRead]:
    return role_service.bulk_create_roles(db, data)


@router.get("/{role_id}", response_model=RoleRead)
def get_role(role_id: int, db: Session = Depends(get_db)) -> RoleRead:
    return RoleRead.model_validate(role_service.get_role(db, role_id))


@router.patch("/{role_id}", response_model=RoleRead)
def update_role(role_id: int, data: RoleUpdate, db: Session = Depends(get_db)) -> RoleRead:
    return RoleRead.model_validate(role_service.update_role(db, role_id, data))


@router.delete("/{role_id}", status_code=204)
def delete_role(role_id: int, db: Session = Depends(get_db)) -> None:
    role_service.delete_role(db, role_id)
