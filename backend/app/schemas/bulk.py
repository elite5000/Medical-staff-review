"""Shared request/response shapes for the `POST .../bulk` endpoints, which create many
entities from one newline-separated paste in the client (see app/lib/widgets/
bulk_add_dialog.dart). Kept in one place because Tags, Roles, Staff and Rooms all take the
same names-only input and return the same created/skipped summary."""

from pydantic import BaseModel, field_validator


class NameListCreate(BaseModel):
    """A batch of entity names. The client splits the pasted text on newlines, but the
    trimming/blank-dropping is enforced here too so the services never see a blank or
    padded name regardless of who calls the API."""

    names: list[str] = []

    @field_validator("names")
    @classmethod
    def _trim_and_drop_blanks(cls, names: list[str]) -> list[str]:
        return [stripped for name in names if (stripped := name.strip())]


class BulkCreateResult[ItemT](BaseModel):
    """`skipped` holds input names rejected as already-existing, which only happens for the
    entities with a UNIQUE name column (Tag, Role); it stays empty for Rooms and Staff,
    whose names may legitimately repeat."""

    created: list[ItemT]
    skipped: list[str] = []
