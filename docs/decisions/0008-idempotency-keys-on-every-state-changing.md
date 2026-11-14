# 0008. Idempotency keys on every state-changing endpoint

**Status:** Accepted (contracts and schema v0.2)

## Context
Networks retry. A retried POST must never create two runs or record two decisions.

## Decision
POST /v1/runs and POST /v1/runs/{id}/decision require an Idempotency-Key header. The runs.idempotency_keys table stores the request hash and the saved response, keyed by (tenant, endpoint, key). The same key with the same body returns the saved response; the same key with a different body returns 409.

## Why
Safe retries are a basic production requirement, especially for approvals.

## Trade-offs
Keys must be cleaned up eventually (a periodic delete of old rows).

## Interview talking point
What happens if the approve button is clicked twice?

## Revisit when
Never; this is a baseline.
