"""Contract tests: every fixture must validate against its model, and key rules must hold.

If you change a model or a fixture, these tests tell you whether the other person's code will break.
"""
import json
import uuid
from decimal import Decimal
from pathlib import Path

import pytest
from contracts.auth import Role, TokenClaims, can_decide
from contracts.common import new_id
from contracts.errors import ErrorResponse
from contracts.invoice import Invoice
from contracts.mcp import (
    ActionOutput,
    CheckerOutput,
    PolicyChunk,
    PolicyOutput,
    PurchaseOrderRecord,
)
from contracts.runs import DecisionRequest, RunCreate, RunDetail, RunStatus
from pydantic import ValidationError

FIXTURES = Path(__file__).resolve().parent.parent / "fixtures"

FOLDER_TO_MODEL = {
    "invoices": Invoice,
    "purchase_orders": PurchaseOrderRecord,
    "policy_chunks": PolicyChunk,
    "errors": ErrorResponse,
    "tokens": TokenClaims,
}
FILE_TO_MODEL = {
    "runs/run_waiting_approval.json": RunDetail,
    "runs/run_done.json": RunDetail,
    "requests/run_create.json": RunCreate,
    "requests/decision_approve.json": DecisionRequest,
    "requests/decision_edit.json": DecisionRequest,
    "agent_outputs/checker_mismatch.json": CheckerOutput,
    "agent_outputs/policy_approval_required.json": PolicyOutput,
    "agent_outputs/action_drafts.json": ActionOutput,
}


def _all_fixture_models():
    for folder, model in FOLDER_TO_MODEL.items():
        for path in sorted((FIXTURES / folder).glob("*.json")):
            yield path, model
    for rel, model in FILE_TO_MODEL.items():
        yield FIXTURES / rel, model


@pytest.mark.parametrize("path,model", list(_all_fixture_models()), ids=lambda v: getattr(v, "name", str(v)))
def test_fixture_matches_contract(path, model):
    model.model_validate_json(path.read_text())


def test_every_fixture_file_is_covered():
    covered = {p for p, _ in _all_fixture_models()}
    on_disk = set(FIXTURES.rglob("*.json"))
    assert on_disk == covered, f"fixtures without a model mapping: {sorted(on_disk - covered)}"


def test_money_is_serialized_as_string():
    inv = Invoice.model_validate_json((FIXTURES / "invoices/mismatched.json").read_text())
    data = json.loads(inv.model_dump_json())
    assert data["total_amount"] == "420000.00"
    assert inv.total_amount == Decimal("420000.00")


def test_floats_are_rejected_for_money():
    raw = json.loads((FIXTURES / "invoices/clean.json").read_text())
    raw["total_amount"] = 95000.0
    with pytest.raises(ValidationError):
        Invoice.model_validate(raw)


def test_unknown_fields_rejected_in_requests():
    raw = json.loads((FIXTURES / "requests/run_create.json").read_text())
    raw["surprise"] = 1
    with pytest.raises(ValidationError):
        RunCreate.model_validate(raw)


def test_bad_currency_rejected():
    raw = json.loads((FIXTURES / "invoices/clean.json").read_text())
    raw["currency"] = "rupees"
    with pytest.raises(ValidationError):
        Invoice.model_validate(raw)


def test_confidence_must_be_between_zero_and_one():
    raw = json.loads((FIXTURES / "invoices/clean.json").read_text())
    raw["confidence"] = {"total_amount": 1.5}
    with pytest.raises(ValidationError):
        Invoice.model_validate(raw)


def test_edit_decision_requires_edits():
    with pytest.raises(ValidationError):
        DecisionRequest(decision="edit", edits=None, comment=None, decided_by="x")


def test_pending_approval_only_while_waiting():
    raw = json.loads((FIXTURES / "runs/run_waiting_approval.json").read_text())
    raw["status"] = "done"
    with pytest.raises(ValidationError):
        RunDetail.model_validate(raw)
    raw = json.loads((FIXTURES / "runs/run_waiting_approval.json").read_text())
    raw["pending_approval"] = None
    with pytest.raises(ValidationError):
        RunDetail.model_validate(raw)


def test_run_status_values_are_exact():
    assert [s.value for s in RunStatus] == [
        "queued", "extracting", "checking", "waiting_approval", "executing", "done", "failed",
    ]


def test_malicious_text_is_just_data_at_schema_level():
    # The schema cannot and should not block prompt injection; guardrails and the allow-list do (Week 8).
    inv = Invoice.model_validate_json((FIXTURES / "invoices/malicious.json").read_text())
    assert "IGNORE ALL PREVIOUS INSTRUCTIONS" in inv.line_items[0].description


def test_only_approver_or_admin_can_decide():
    assert can_decide([Role.approver])
    assert can_decide([Role.admin])
    assert not can_decide([Role.viewer, Role.reviewer])


def test_new_id_is_a_uuid():
    assert isinstance(new_id(), uuid.UUID)
