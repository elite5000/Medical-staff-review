import enum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Enum, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

if TYPE_CHECKING:
    from app.models.building import Building
    from app.models.role import Role
    from app.models.tag import Tag


class RuleType(enum.StrEnum):
    MINIMUM_COUNT = "minimum_count"
    ELIGIBILITY_RESTRICTION = "eligibility_restriction"


class Rule(Base):
    """
    Exactly two shapes, discriminated by rule_type (see CONTEXT.md):
      - minimum_count: "this Building or Tag needs >= minimum_count staff holding role_id".
        Attaches to exactly one of building_id / tag_id.
      - eligibility_restriction: "only role_id may work in rooms with tag_id".
        Attaches only to tag_id.
    The CHECK constraint is the source of truth; service-layer validation re-checks it
    since SQLite's ALTER-time CHECK support is limited for future schema changes.
    """

    __tablename__ = "rules"
    __table_args__ = (
        CheckConstraint(
            "(rule_type = 'eligibility_restriction' AND tag_id IS NOT NULL "
            " AND building_id IS NULL AND minimum_count IS NULL) "
            "OR "
            "(rule_type = 'minimum_count' AND minimum_count >= 1 "
            " AND ((building_id IS NOT NULL AND tag_id IS NULL) "
            "      OR (building_id IS NULL AND tag_id IS NOT NULL)))",
            name="ck_rule_shape",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column()
    # values_callable: store the enum's *value* ("minimum_count") in the DB column, not its
    # member name ("MINIMUM_COUNT") — SQLAlchemy's default, which the ck_rule_shape CHECK
    # constraint above (written against the lowercase values) would otherwise never match.
    rule_type: Mapped[RuleType] = mapped_column(
        Enum(RuleType, values_callable=lambda enum_cls: [member.value for member in enum_cls])
    )
    role_id: Mapped[int] = mapped_column(ForeignKey("roles.id"))
    building_id: Mapped[int | None] = mapped_column(ForeignKey("buildings.id"), default=None)
    tag_id: Mapped[int | None] = mapped_column(ForeignKey("tags.id"), default=None)
    minimum_count: Mapped[int | None] = mapped_column(default=None)

    role: Mapped["Role"] = relationship()
    building: Mapped["Building | None"] = relationship()
    tag: Mapped["Tag | None"] = relationship()
