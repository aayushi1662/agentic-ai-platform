"""MCP tool contracts and agent output shapes (contract 5.4 and 5.5)."""
from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import Field

from .common import Currency, Money, Percent, Quantity, RequestModel, ResponseModel
from .runs import DraftType, ToRole


class PoStatus(StrEnum):
    open = "open"
    closed = "closed"
    cancelled = "cancelled"


class PoLineItem(ResponseModel):
    description: str
    quantity: Quantity
    unit_price: Money
    amount: Money


class PurchaseOrderRecord(ResponseModel):
    po_number: str
    tenant_id: UUID
    vendor_name: str
    currency: Currency
    ordered_total: Money
    line_items: list[PoLineItem]
    status: PoStatus
    created_at: datetime


class PolicyChunk(ResponseModel):
    chunk_id: UUID
    document_title: str
    text: str
    score: float
    source_path: str


class EmailDraft(ResponseModel):
    subject: str
    body: str


class ActionResult(ResponseModel):
    result: str
    executed_at: datetime


# ---- tool argument models (what an agent sends to each MCP tool) ----

class GetPurchaseOrderArgs(RequestModel):
    po_number: str
    tenant_id: UUID


class SearchPoliciesArgs(RequestModel):
    query: str
    tenant_id: UUID
    top_k: int = Field(default=5, ge=1, le=20)


class DraftEmailArgs(RequestModel):
    recipient_type: ToRole
    draft_type: DraftType
    context: str
    tenant_id: UUID


class PostApprovedActionArgs(RequestModel):
    """Refused by the server unless a recorded approval exists for run_id."""

    run_id: UUID
    action: str
    approval_id: UUID


# ---- agent outputs stored inside run steps ----

class Mismatch(ResponseModel):
    field: str
    invoice_value: str | None
    po_value: str | None


class CheckerOutput(ResponseModel):
    po_found: bool
    variance_amount: Money | None = None
    variance_percent: Percent | None = None
    mismatches: list[Mismatch] = Field(default_factory=list)
    duplicate_run_ids: list[UUID] = Field(default_factory=list)


class RuleOutcome(StrEnum):
    approval_required = "approval_required"
    allowed = "allowed"
    flagged = "flagged"
    blocked = "blocked"


class RuleApplied(ResponseModel):
    rule_id: str
    title: str
    source_chunk_id: UUID
    outcome: RuleOutcome


class PolicyOutput(ResponseModel):
    rules_applied: list[RuleApplied]
    approval_required: bool
    reasons: list[str]


class ActionDraft(ResponseModel):
    type: DraftType
    to_role: ToRole
    subject: str
    body: str


class ActionOutput(ResponseModel):
    drafts: list[ActionDraft]
