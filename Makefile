# On Windows, run these commands inside WSL2, or copy the commands by hand.
PSQL ?= docker compose exec -T postgres psql -U postgres -d platform

.PHONY: up down db-migrate db-test db-reset test lint dev-keys check

up:            ## start Postgres and Valkey
	docker compose up -d
	docker compose ps

down:          ## stop containers (keeps data)
	docker compose down

db-migrate:    ## apply bootstrap and service migrations (safe to repeat)
	PSQL="$(PSQL)" ./scripts/migrate.sh

db-test:       ## run database safety tests (tenant isolation, append-only audit log, vector search)
	$(PSQL) -q -v ON_ERROR_STOP=1 -f - < infra/db/tests/rls_test.sql

db-reset:      ## DANGER: delete all local data and start clean
	docker compose down -v
	$(MAKE) up
	sleep 5
	$(MAKE) db-migrate

test:          ## run contract tests
	cd contracts && python -m pytest -q

lint:          ## style checks
	ruff check .

dev-keys:      ## create local JWT signing keys (never commit them)
	./scripts/gen_dev_keys.sh

check: lint test db-test   ## everything CI runs
