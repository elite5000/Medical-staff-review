from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.building import Building
from app.models.role import Role
from app.models.roster import RosterViolation
from app.models.rule import Rule
from app.models.tag import Tag
from app.schemas.rule import RuleCreate


def list_rules(db: Session) -> list[Rule]:
    return list(db.scalars(select(Rule).order_by(Rule.id)))


def get_rule(db: Session, rule_id: int) -> Rule:
    rule = db.get(Rule, rule_id)
    if rule is None:
        raise HTTPException(status_code=404, detail="Rule not found")
    return rule


def create_rule(db: Session, data: RuleCreate) -> Rule:
    if db.get(Role, data.role_id) is None:
        raise HTTPException(status_code=422, detail=f"Unknown role_id: {data.role_id}")
    if data.building_id is not None and db.get(Building, data.building_id) is None:
        raise HTTPException(status_code=422, detail=f"Unknown building_id: {data.building_id}")
    if data.tag_id is not None and db.get(Tag, data.tag_id) is None:
        raise HTTPException(status_code=422, detail=f"Unknown tag_id: {data.tag_id}")

    rule = Rule(**data.model_dump())
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


def delete_rule(db: Session, rule_id: int) -> None:
    rule = get_rule(db, rule_id)
    referenced = db.scalar(
        select(RosterViolation.id).where(RosterViolation.rule_id == rule_id).limit(1)
    )
    if referenced:
        raise HTTPException(
            status_code=409,
            detail="Cannot delete a Rule referenced by a past Roster's violation history",
        )
    db.delete(rule)
    db.commit()
