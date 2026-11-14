#!/usr/bin/env bash
# Applies infra/db/bootstrap/*.sql and services/*/migrations/*.sql in order, once each.
# Usage:
#   PSQL="docker compose exec -T postgres psql -U postgres -d platform" ./scripts/migrate.sh
#   PSQL="psql postgresql://postgres:postgres@localhost:5432/platform" ./scripts/migrate.sh   # CI or local psql
# This is a simple bootstrap runner. Person B converts the runs and erp migrations to Alembic revisions in Week 1
# (an Alembic revision can run these same SQL files with op.execute).
set -euo pipefail
: "${PSQL:?set PSQL, see the usage comment at the top of this file}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

$PSQL -v ON_ERROR_STOP=1 -q -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());"

cd "$ROOT"
for f in $(ls infra/db/bootstrap/*.sql services/*/migrations/*.sql 2>/dev/null); do
  applied=$($PSQL -tA -c "SELECT 1 FROM public.schema_migrations WHERE name = '$f'")
  if [ "$applied" = "1" ]; then
    echo "skip   $f"
  else
    echo "apply  $f"
    $PSQL -v ON_ERROR_STOP=1 -q -1 -f - < "$f"
    $PSQL -v ON_ERROR_STOP=1 -q -c "INSERT INTO public.schema_migrations (name) VALUES ('$f')"
  fi
done
echo "migrations complete"
