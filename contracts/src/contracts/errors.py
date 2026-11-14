from __future__ import annotations

from typing import Any

from pydantic import Field

from .common import ResponseModel


class ErrorBody(ResponseModel):
    code: str
    message: str
    details: dict[str, Any] = Field(default_factory=dict)


class ErrorResponse(ResponseModel):
    """Error format used by every service.

    HTTP codes: 400 bad request, 401 unauthenticated, 403 forbidden, 404 not found,
    409 conflict, 422 validation error, 500 server error.
    """

    error: ErrorBody
