"""
Import every model module here so Base.metadata is fully populated (needed for Alembic
autogenerate and so relationship() string references resolve regardless of import order).
"""

from app.models.associations import room_tags, staff_roles
from app.models.building import Building
from app.models.role import Role
from app.models.room import Room
from app.models.roster import Roster, RosterViolation, ViolationType
from app.models.rule import Rule, RuleType
from app.models.settings import AppSettings
from app.models.shift import Shift
from app.models.staff import PreferredDay, Staff, Unavailability
from app.models.tag import Tag

__all__ = [
    "AppSettings",
    "Building",
    "PreferredDay",
    "Role",
    "Room",
    "Roster",
    "RosterViolation",
    "Rule",
    "RuleType",
    "Shift",
    "Staff",
    "Tag",
    "Unavailability",
    "ViolationType",
    "room_tags",
    "staff_roles",
]
