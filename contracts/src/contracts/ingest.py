from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from uuid import UUID

from .common import Currency, Money, RequestModel, ResponseModel
from .invoice import InvoiceResponse


class DocumentStatus(StrEnum):
    queued = "queued"
    extracting = "extracting"
    extracted = "extracted"
    failed = "failed"


class DocumentCreated(ResponseModel):
    document_id: UUID
    status: DocumentStatus


class DocumentDetail(ResponseModel):
    document_id: UUID
    tenant_id: UUID
    filename: str
    status: DocumentStatus
    invoice: InvoiceResponse | None = None
    created_at: datetime


class DocumentSummary(ResponseModel):
    document_id: UUID
    filename: str
    status: DocumentStatus
    created_at: datetime


class DocumentList(ResponseModel):
    items: list[DocumentSummary]
    next_cursor: str | None = None


class InvoicePatch(RequestModel):
    """PATCH /v1/documents/{id}/invoice from the review screen.

    Every field is optional. Each accepted patch creates a new invoice version with source 'human';
    the model's original output is never overwritten.
    """

    invoice_number: str | None = None
    vendor_name: str | None = None
    po_number: str | None = None
    invoice_date: date | None = None
    due_date: date | None = None
    currency: Currency | None = None
    total_amount: Money | None = None
