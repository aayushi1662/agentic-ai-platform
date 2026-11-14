# services/ingest (owner: Himanshi, Person A)

Django + Django REST Framework + Celery. Reader agent (OCR, parsing, structured output).

Your tables live in the Postgres schema `ingest` and are created by Django migrations. Do not create tables in other schemas.
Connect with `INGEST_DATABASE_URL` (role `ingest_svc`). Set the Django database `search_path` to `ingest,public`.

## Django model spec (reference; adapt names to Django conventions but keep the columns and rules)

| Table | Columns | Rules |
|---|---|---|
| tenants | id uuid PK, name, slug (unique), is_active, created_at | Identity of a customer. Other services reference only the id |
| tenant_members | id, tenant_id, user_id (Django user), role (viewer, reviewer, approver, admin) | Unique (tenant_id, user_id) |
| documents | id uuid PK, tenant_id, filename, content_type, storage_path, sha256, status (queued, extracting, extracted, failed), error (json, nullable), uploaded_by, created_at, updated_at, deleted_at (nullable) | Soft delete. Index (tenant_id, status, created_at) |
| invoice_versions | id uuid PK, tenant_id, document_id, version int, source (model or human), data jsonb (the Invoice contract), model_name (nullable), prompt_version (nullable), created_by (nullable), created_at | Unique (document_id, version). **Immutable: never update or delete** (ADR 0006) |
| extraction_attempts | id uuid PK, tenant_id, document_id, model_name, prompt_version, input_tokens, output_tokens, latency_ms, schema_valid bool, retries int, error jsonb, created_at | One row per Reader call. Feeds the accuracy and cost dashboards |

## Rules for this service

- Every query must filter by tenant. Use a custom manager or queryset so forgetting is impossible.
- Validate every Reader output with `contracts.invoice.Invoice` before saving. Retry on invalid JSON.
- Issue JWTs signed RS256 with the private key (`JWT_PRIVATE_KEY_PATH`). Never share the private key.
- Follow the API in `contracts/src/contracts/ingest.py`. Routes start with `/v1`.
- Week 8: enable Row-Level Security on these tables (ADR 0014).
