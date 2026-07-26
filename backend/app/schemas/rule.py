from pydantic import BaseModel, ConfigDict, model_validator

from app.models.rule import RuleType


class RuleBase(BaseModel):
    """
    Mirrors the DB-level ck_rule_shape CHECK constraint (see app/models/rule.py) at the API
    boundary, so invalid combinations are rejected with a clear 422 instead of a raw
    IntegrityError from SQLite.
    """

    name: str
    rule_type: RuleType
    role_id: int
    building_id: int | None = None
    tag_id: int | None = None
    minimum_count: int | None = None

    @model_validator(mode="after")
    def check_shape(self) -> "RuleBase":
        if self.rule_type is RuleType.ELIGIBILITY_RESTRICTION:
            if self.tag_id is None:
                raise ValueError("eligibility_restriction rules must set tag_id")
            if self.building_id is not None or self.minimum_count is not None:
                raise ValueError(
                    "eligibility_restriction rules must not set building_id or minimum_count"
                )
        else:  # MINIMUM_COUNT
            if self.minimum_count is None or self.minimum_count < 1:
                raise ValueError("minimum_count rules must set minimum_count >= 1")
            has_building = self.building_id is not None
            has_tag = self.tag_id is not None
            if has_building == has_tag:  # both set or neither set
                raise ValueError(
                    "minimum_count rules must set exactly one of building_id or tag_id"
                )
        return self


class RuleCreate(RuleBase):
    pass


class RuleRead(RuleBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
