# Data design (contracts and schema v0.2)

Source of truth: `/contracts` (API shapes) and `services/*/migrations/*.sql` (runs, knowledge, erp, evals tables).
The `ingest` tables are Django models that Person A creates from the spec in `services/ingest/README.md`.

## Who owns what

| Schema | Owner | Contents |
|---|---|---|
| ingest | Person A (Himanshi) | tenants, members, documents, invoice versions, extraction attempts |
| runs | Person B (Aayushi) | runs, steps, tool calls, approvals, drafts, audit log, idempotency keys, LLM call log, tenant settings |
| knowledge | Person B | policy documents and chunks (text, keyword index, embeddings) |
| erp | Person B | mock ERP: vendors, purchase orders, PO lines |
| evals | shared | eval datasets, runs, and results |

Services reference each other only by ID and talk through APIs. There are no foreign keys across schemas.

## How one invoice flows through the data

1. Upload: `ingest.documents` row (status queued). A Celery job runs the Reader agent.
2. Extraction: `ingest.invoice_versions` version 1 (source model) and one `ingest.extraction_attempts` row.
3. Review: a correction creates version 2 (source human). Versions are never edited.
4. Start run: the UI or ingest calls `POST /v1/runs` with the invoice. A `runs.runs` row is created.
5. Workflow: `runs.run_steps` and `runs.tool_calls` rows record each agent step. The Checker reads the ERP through MCP and also checks `runs.runs` for the same vendor and invoice number (duplicate detection).
6. Pause: status `waiting_approval`; drafts are saved in `runs.drafts`.
7. Decision: one immutable `runs.approvals` row; the run resumes.
8. Throughout: `runs.audit_log` receives an append-only entry for each important event.

## Rules every table follows

- Tenant tables have `tenant_id uuid NOT NULL` and Row-Level Security (runs, knowledge, erp now; ingest in Week 8, ADR 0014).
- Child tables use composite foreign keys `(tenant_id, parent_id)` so a child cannot cross tenants.
- Timestamps are `timestamptz` in UTC. Money is `NUMERIC(14,2)` with a separate currency code.
- Append-only tables (audit_log, approvals) have a trigger that blocks UPDATE, DELETE, and TRUNCATE.

## Using Row-Level Security from your code

Set the tenant once per request, inside the transaction, using the transaction-local form:

```python
# SQLAlchemy (runs service)
await session.execute(text("SELECT set_config('app.tenant_id', :t, true)"), {"t": str(tenant_id)})

# Django (ingest service): in middleware, inside an atomic request
with connection.cursor() as cur:
    cur.execute("SELECT set_config('app.tenant_id', %s, true)", [str(tenant_id)])
```

If the setting is missing, queries return no rows (fail closed). Verify with `make db-test`.

## Known caveat: filtered vector search

With an approximate (HNSW) index, a tenant filter can reduce the number of rows returned below `top_k`.
Options: raise the index's search setting, or use iterative index scans if your pgvector version supports them
(check the pgvector documentation for your version). Measure recall@k with the tenant filter on.
