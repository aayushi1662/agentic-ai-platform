# 0003. Migration tools: Django migrations for ingest; SQLAlchemy 2.0 + Alembic for runs and erp

**Status:** Accepted (contracts and schema v0.2)

## Context
Person A uses Django; Person B uses FastAPI, which has no built-in ORM or migrations.

## Decision
ingest tables are Django models and migrations. runs, knowledge, erp, and evals use SQL migrations now (services/*/migrations/*.sql, applied by scripts/migrate.sh) and are wrapped as Alembic revisions in Week 1 (an Alembic revision can run these SQL files with op.execute). Both tools are open source.

## Why
Each person uses the migration tool natural to their framework, and nothing needs to share a migration history.

## Trade-offs
Two migration tools to learn. Do not let Django manage tables in schemas it does not own.

## Interview talking point
Why two migration tools? Answer: ownership boundaries (ADR 0002).

## Revisit when
Both services move to one framework.
