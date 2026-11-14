from __future__ import annotations

from enum import StrEnum
from uuid import UUID

from .common import ResponseModel


class Role(StrEnum):
    viewer = "viewer"
    reviewer = "reviewer"
    approver = "approver"
    admin = "admin"


class TokenClaims(ResponseModel):
    """Claims inside the RS256 JWT issued by the ingest (Django) service.

    Only the ingest service holds the private key. Every other service verifies with the public key.
    """

    sub: str
    tenant_id: UUID
    roles: list[Role]
    iss: str | None = None
    exp: int


def can_decide(roles: list[Role]) -> bool:
    """Only approvers and admins may post an approval decision."""
    return Role.approver in roles or Role.admin in roles
