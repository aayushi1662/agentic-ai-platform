# 0010. API versioning: every route starts with /v1

**Status:** Accepted (contracts and schema v0.2)

## Context
Breaking changes are inevitable; clients need a stable path.

## Decision
All service routes are prefixed with /v1 (for example POST /v1/runs, GET /v1/documents/{id}).

## Why
Versioning is cheap now and painful to add later.

## Trade-offs
Slightly longer URLs.

## Interview talking point
How do you evolve an API without breaking clients?

## Revisit when
A breaking change appears; add /v2 beside /v1.
