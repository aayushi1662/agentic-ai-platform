-- 00_bootstrap.sql: run as the admin role. Safe to run more than once (idempotent).
-- DEV ONLY: role passwords below are placeholders. Never reuse them outside your laptop.

CREATE EXTENSION IF NOT EXISTS vector;

DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['ingest_svc', 'runs_svc', 'erp_svc', 'eval_svc'] LOOP
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', r, 'dev_only_change_me');
    END IF;
  END LOOP;
END $$;

-- One Postgres schema per owner. No foreign keys across schemas: services reference each other by ID only.
CREATE SCHEMA IF NOT EXISTS ingest AUTHORIZATION ingest_svc;  -- Person A (Django migrations create the tables)
CREATE SCHEMA IF NOT EXISTS runs;                              -- Person B
CREATE SCHEMA IF NOT EXISTS knowledge;                         -- Person B (RAG data)
CREATE SCHEMA IF NOT EXISTS erp;                               -- Person B (mock ERP)
CREATE SCHEMA IF NOT EXISTS evals;                             -- shared quality results

GRANT USAGE ON SCHEMA runs, knowledge TO runs_svc;
GRANT USAGE ON SCHEMA erp TO erp_svc;
GRANT USAGE ON SCHEMA evals TO eval_svc, runs_svc;

ALTER ROLE ingest_svc SET search_path = ingest, public;
ALTER ROLE runs_svc   SET search_path = runs, knowledge, public;
ALTER ROLE erp_svc    SET search_path = erp, public;
ALTER ROLE eval_svc   SET search_path = evals, public;

-- Shared helper used by triggers in several schemas.
CREATE OR REPLACE FUNCTION public.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'append-only table: % is not allowed on %', TG_OP, TG_TABLE_NAME;
END $$;
