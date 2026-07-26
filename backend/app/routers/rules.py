from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.rule import RuleCreate, RuleRead
from app.services import rule_service

router = APIRouter(prefix="/rules", tags=["rules"])


@router.get("", response_model=list[RuleRead])
def list_rules(db: Session = Depends(get_db)) -> list[RuleRead]:
    return [RuleRead.model_validate(r) for r in rule_service.list_rules(db)]


@router.post("", response_model=RuleRead, status_code=201)
def create_rule(data: RuleCreate, db: Session = Depends(get_db)) -> RuleRead:
    return RuleRead.model_validate(rule_service.create_rule(db, data))


@router.get("/{rule_id}", response_model=RuleRead)
def get_rule(rule_id: int, db: Session = Depends(get_db)) -> RuleRead:
    return RuleRead.model_validate(rule_service.get_rule(db, rule_id))


@router.delete("/{rule_id}", status_code=204)
def delete_rule(rule_id: int, db: Session = Depends(get_db)) -> None:
    rule_service.delete_rule(db, rule_id)
