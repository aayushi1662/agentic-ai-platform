from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from typing import Any
from uuid import UUID

from pydantic import Field, model_validator

from .common import RequestModel, ResponseModel
from .errors import ErrorBody
from .invoice import Invoice


class RunStatus(StrEnum):
    queued = "queued"
    extracting = "extracting"
    checking = "checking"
    waiting_approval = "waiting_approval"
    executing = "executing"
    done = "done"
    failed = "failed"


class StepStatus(StrEnum):
    pending = "pending"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"


class AgentName(StrEnum):
    reader = "reader"
    checker = "checker"
    policy = "policy"
    action = "action"
    executor = "executor"
    system = "system"


class DecisionType(StrEnum):
    approve = "approve"
    edit = "edit"
    reject = "reject"


class DraftType(StrEnum):
    vendor_email = "vendor_email"
    approval_request = "approval_request"


class ToRole(StrEnum):
    vendor = "vendor"
    manager = "manager"


class ToolCall(ResponseModel):
    tool: str
    arguments: dict[str, Any]
    result_summary: str
    duration_ms: int


class Draft(ResponseModel):
    type: DraftType
    to_role: ToRole
    subject: str
    body: str


class Step(ResponseModel):
    step_id: UUID
    name: str
    agent: AgentName
    status: StepStatus
    started_at: datetime | None = None
    ended_at: datetime | None = None
    input: dict[str, Any] = Field(default_factory=dict)
    output: dict[str, Any] = Field(default_factory=dict)
    tool_calls: list[ToolCall] = Field(default_factory=list)
    error: ErrorBody | None = None


class PendingApproval(ResponseModel):
    reasons: list[str]
    drafts: list[Draft]


class RunCreate(RequestModel):
    """POST /v1/runs body. Send an Idempotency-Key header so retries never create two runs."""

    document_id: UUID
    tenant_id: UUID
    invoice: Invoice


class RunCreated(ResponseModel):
    run_id: UUID
    status: RunStatus


class RunDetail(ResponseModel):
    """GET /v1/runs/{run_id}. pending_approval is set only while status is waiting_approval."""

    run_id: UUID
    tenant_id: UUID
    document_id: UUID
    status: RunStatus
    created_at: datetime
    updated_at: datetime
    steps: list[Step]
    pending_approval: PendingApproval | None = None
    result: dict[str, Any] | None = None

    @model_validator(mode="after")
    def _pending_only_when_waiting(self) -> RunDetail:
        waiting = self.status == RunStatus.waiting_approval
        if waiting and self.pending_approval is None:
            raise ValueError("pending_approval is required while status is waiting_approval")
        if not waiting and self.pending_approval is not None:
            raise ValueError("pending_approval must be null unless status is waiting_approval")
        return self


class RunSummary(ResponseModel):
    run_id: UUID
    document_id: UUID
    status: RunStatus
    vendor_name: str
    invoice_number: str
    created_at: datetime


class RunList(ResponseModel):
    items: list[RunSummary]
    next_cursor: str | None = None


class DecisionRequest(RequestModel):
    """POST /v1/runs/{run_id}/decision. Only approver or admin roles may call it.

    Send an Idempotency-Key header.
    """

    decision: DecisionType
    edits: dict[str, Any] | None = None
    comment: str | None = None
    decided_by: str

    @model_validator(mode="after")
    def _edit_needs_edits(self) -> DecisionRequest:
        if self.decision == DecisionType.edit and not self.edits:
            raise ValueError("edits are required when decision is 'edit'")
        return self


class DecisionResponse(ResponseModel):
    run_id: UUID
    status: RunStatus
