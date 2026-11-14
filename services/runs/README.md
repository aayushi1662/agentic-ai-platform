# services/runs (owner: Aayushi, Person B)

FastAPI + LangGraph workflow service. Tables: schemas `runs`, `knowledge`, and `evals`
(see `migrations/`). Connect with `RUNS_DATABASE_URL` (role `runs_svc`).

Week 1: wrap the SQL migrations as Alembic revisions, add a database session helper that sets
`app.tenant_id` on every request (see docs/data-design.md), and add a health endpoint.
Follow the API in `contracts/src/contracts/runs.py`. Routes start with `/v1`.
