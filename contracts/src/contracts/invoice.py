from __future__ import annotations

from datetime import date

from pydantic import field_validator

from .common import Currency, Money, Quantity, RequestModel, ResponseModel


class LineItem(RequestModel):
    description: str
    quantity: Quantity
    unit_price: Money
    amount: Money


class Invoice(RequestModel):
    """Output of the Reader agent and input to the runs service (contract 5.1).

    Required: invoice_number, vendor_name, invoice_date, currency, total_amount, line_items (may be empty).
    Nullable: po_number, due_date. confidence is optional, values 0 to 1.
    We deliberately do not require the line items to sum to the total (taxes, shipping, rounding).
    """

    invoice_number: str
    vendor_name: str
    po_number: str | None = None
    invoice_date: date
    due_date: date | None = None
    currency: Currency
    total_amount: Money
    line_items: list[LineItem]
    confidence: dict[str, float] | None = None

    @field_validator("confidence")
    @classmethod
    def _confidence_range(cls, v: dict[str, float] | None) -> dict[str, float] | None:
        if v is not None:
            for key, score in v.items():
                if not 0.0 <= score <= 1.0:
                    raise ValueError(f"confidence for {key} must be between 0 and 1")
        return v


class InvoiceResponse(Invoice, ResponseModel):
    """Same fields as Invoice, but tolerant of extra fields when read back from a service."""
