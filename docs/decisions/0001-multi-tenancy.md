# 0001. Multi-tenancy: one database, tenant_id everywhere, Row-Level Security

**Status:** Accepted (contracts and schema v0.2)

## Context
We serve several customers (tenants) from one system and must never leak data between them.

## Decision
Every tenant table has a tenant_id column. Postgres Row-Level Security (RLS) policies compare it with the session setting app.tenant_id, which the service sets once per request inside the transaction (`SELECT set_config('app.tenant_id', '<uuid>', true)`). No tenant set means no rows. Child tables use composite foreign keys (tenant_id, id) so a child can never point at another tenant's parent.

## Why
The database enforces isolation even if application code has a bug. It is cheap to run and easy to test (see infra/db/tests/rls_test.sql).

## Trade-offs
Services must set the tenant on every request and use a transaction. Connection pools are safe only because the setting is transaction-local (the `true` argument). Schema-per-tenant gives stronger isolation but makes migrations and onboarding harder.

## Interview talking point
How did you stop one customer from reading another's data? Answer: app filtering plus database-enforced RLS, tested with a cross-tenant test, plus composite foreign keys.

## Revisit when
A customer needs physical separation (then move that tenant to its own database).
