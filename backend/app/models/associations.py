from sqlalchemy import Column, ForeignKey, Table

from app.db import Base

room_tags = Table(
    "room_tags",
    Base.metadata,
    Column("room_id", ForeignKey("rooms.id"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id"), primary_key=True),
)

staff_roles = Table(
    "staff_roles",
    Base.metadata,
    Column("staff_id", ForeignKey("staff.id"), primary_key=True),
    Column("role_id", ForeignKey("roles.id"), primary_key=True),
)
