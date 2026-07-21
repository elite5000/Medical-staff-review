from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.building import BuildingCreate, BuildingRead, BuildingUpdate
from app.services import building_service

router = APIRouter(prefix="/buildings", tags=["buildings"])


@router.get("", response_model=list[BuildingRead])
def list_buildings(db: Session = Depends(get_db)) -> list[BuildingRead]:
    return [BuildingRead.model_validate(b) for b in building_service.list_buildings(db)]


@router.post("", response_model=BuildingRead, status_code=201)
def create_building(data: BuildingCreate, db: Session = Depends(get_db)) -> BuildingRead:
    return BuildingRead.model_validate(building_service.create_building(db, data))


@router.get("/{building_id}", response_model=BuildingRead)
def get_building(building_id: int, db: Session = Depends(get_db)) -> BuildingRead:
    return BuildingRead.model_validate(building_service.get_building(db, building_id))


@router.patch("/{building_id}", response_model=BuildingRead)
def update_building(
    building_id: int, data: BuildingUpdate, db: Session = Depends(get_db)
) -> BuildingRead:
    return BuildingRead.model_validate(building_service.update_building(db, building_id, data))


@router.delete("/{building_id}", status_code=204)
def delete_building(building_id: int, db: Session = Depends(get_db)) -> None:
    building_service.delete_building(db, building_id)
