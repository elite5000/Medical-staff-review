from pydantic import BaseModel, ConfigDict


class RoleBase(BaseModel):
    name: str


class RoleCreate(RoleBase):
    pass


class RoleUpdate(BaseModel):
    name: str | None = None


class RoleRead(RoleBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class RoleApplyToStaff(BaseModel):
    """Body of POST /roles/{role_id}/apply-to-staff — the Staff to additively grant the Role to."""

    staff_ids: list[int]
