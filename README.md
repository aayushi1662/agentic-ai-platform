# Agentic AI Back-Office Automation Platform

Reads invoices, checks them against a mock ERP and company policy, drafts replies, and waits for human approval.
Built by two engineers in 12 weeks, fully open source.

- **Himanshi (Person A):** Slice 1, Document Intelligence (`services/ingest`, upload and review UI).
- **Aayushi (Person B):** Slice 2, Policy and Action (`services/runs`, `mock_erp`, `mcp_servers`, run timeline and approval UI).

## Repo map

| Path | What |
|---|---|
| `contracts/` | Shared Pydantic models and JSON fixtures. Changes need both teammates (ADR 0013) |
| `infra/db/` | Database bootstrap (roles, schemas) and safety tests |
| `services/` | One folder per service, each with its own README and owner |
| `docs/decisions/` | Why we chose what we chose (14 decisions) |
| `docs/data-design.md` | How data flows and the rules every table follows |
| `docs/handoff/` | Session handoff notes between the two of you |
| `scripts/` | Migration runner, dev keys, dev tokens |

## First 30 minutes on a new laptop

```bash
git clone <repo-url> && cd <repo>
cp .env.example .env                  # fill in LLM_MODEL_NAME for your laptop's RAM
python -m venv .venv && source .venv/bin/activate     # Windows: use WSL2
pip install -e "./contracts[dev]"       # also installs pytest, ruff, pyjwt
make up                               # Postgres + pgvector and Valkey
make db-migrate                       # create roles, schemas, tables
make check                            # lint + contract tests + database safety tests
make dev-keys                         # local JWT keys (git-ignored)
python scripts/dev_token.py --tenant 11111111-1111-4111-8111-111111111111 --role approver
```

All three checks in `make check` must pass before you write any code.

## Ports

Postgres 5432, Valkey 6379, ingest 8000, runs 8001, mock ERP 8002, MCP servers 8010+, Ollama 11434, frontend 3000, tracing UI 3100.
Read ports from environment variables; never hardcode them.

## Rules

- `main` is protected. Work on branches like `feat/ingest-upload-api`. Every PR is reviewed by the other person, who asks at least one "why" question.
- Do not change anything in `contracts/` or rename an environment variable without both teammates approving.
- Never commit `.env` or `.dev-keys/`.
- Synthetic data only.

## Troubleshooting

- `make` not found on Windows: use WSL2, or run the commands from the Makefile by hand.
- Port already in use: change the port in `.env` and `docker-compose.yml`.
- Out of memory: use a smaller local model and start only the services you need.
- Line-ending noise in diffs: `.gitattributes` forces LF; run `git add --renormalize .` once.
