-- Owner: Person B. Tables for the workflow service. Every tenant table carries tenant_id and Row-Level Security.
-- Row-Level Security reads the tenant from the session setting app.tenant_id, which the service sets
-- once per request inside the transaction:  SELECT set_config('app.tenant_id', '<uuid>', true);

CREATE TABLE runs.runs (
  run_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL,
  document_id   uuid NOT NULL,
  status        text NOT NULL DEFAULT 'queued'
                CHECK (status IN ('queued','extracting','checking','waiting_approval','executing','done','failed')),
  invoice       jsonb NOT NULL,
  vendor_name   text NOT NULL,
  invoice_number text NOT NULL,
  trace_id      text,
  result        jsonb,
  error         jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  completed_at  timestamptz,
  UNIQUE (tenant_id, run_id)               -- lets child tables use a composite FK that forces the same tenant
);
CREATE INDEX runs_tenant_status_idx ON runs.runs (tenant_id, status, created_at DESC);
CREATE INDEX runs_duplicate_check_idx ON runs.runs (tenant_id, vendor_name, invoice_number);
CREATE TRIGGER runs_touch BEFORE UPDATE ON runs.runs FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TABLE runs.run_steps (
  step_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL,
  run_id      uuid NOT NULL,
  seq         int  NOT NULL,
  name        text NOT NULL,
  agent       text NOT NULL CHECK (agent IN ('reader','checker','policy','action','executor','system')),
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','succeeded','failed')),
  started_at  timestamptz,
  ended_at    timestamptz,
  input       jsonb NOT NULL DEFAULT '{}'::jsonb,
  output      jsonb NOT NULL DEFAULT '{}'::jsonb,
  error       jsonb,
  UNIQUE (tenant_id, step_id),
  UNIQUE (run_id, seq),
  FOREIGN KEY (tenant_id, run_id) REFERENCES runs.runs (tenant_id, run_id)
);

CREATE TABLE runs.tool_calls (
  tool_call_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL,
  run_id         uuid NOT NULL,
  step_id        uuid NOT NULL,
  tool           text NOT NULL,
  arguments      jsonb NOT NULL,
  result_summary text,
  result         jsonb,
  duration_ms    int,
  error          jsonb,
  created_at     timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, run_id)  REFERENCES runs.runs (tenant_id, run_id),
  FOREIGN KEY (tenant_id, step_id) REFERENCES runs.run_steps (tenant_id, step_id)
);

-- One row per human decision. Immutable: decisions are never edited, only added.
CREATE TABLE runs.approvals (
  approval_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL,
  run_id      uuid NOT NULL,
  pause_seq   int  NOT NULL DEFAULT 1,
  decision    text NOT NULL CHECK (decision IN ('approve','edit','reject')),
  edits       jsonb,
  comment     text,
  decided_by  text NOT NULL,
  decided_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (run_id, pause_seq),
  UNIQUE (tenant_id, approval_id),
  FOREIGN KEY (tenant_id, run_id) REFERENCES runs.runs (tenant_id, run_id),
  CHECK (decision <> 'edit' OR edits IS NOT NULL)
);

CREATE TABLE runs.drafts (
  draft_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL,
  run_id     uuid NOT NULL,
  type       text NOT NULL CHECK (type IN ('vendor_email','approval_request')),
  to_role    text NOT NULL CHECK (to_role IN ('vendor','manager')),
  subject    text NOT NULL,
  body       text NOT NULL,
  status     text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','sent','discarded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, run_id) REFERENCES runs.runs (tenant_id, run_id)
);

-- Append-only audit trail. prev_hash and row_hash are optional now so a tamper-evident hash chain
-- can be added later (stretch goal) without a migration.
CREATE TABLE runs.audit_log (
  audit_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id  uuid NOT NULL,
  run_id     uuid,
  actor      text NOT NULL,
  actor_type text NOT NULL CHECK (actor_type IN ('user','agent','system')),
  action     text NOT NULL,
  details    jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  prev_hash  bytea,
  row_hash   bytea
);
CREATE INDEX audit_tenant_time_idx ON runs.audit_log (tenant_id, created_at DESC);

-- Makes retries safe: the same Idempotency-Key on the same endpoint returns the saved response.
CREATE TABLE runs.idempotency_keys (
  tenant_id       uuid NOT NULL,
  endpoint        text NOT NULL,
  key             text NOT NULL,
  request_hash    text NOT NULL,
  response_status int,
  response_body   jsonb,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, endpoint, key)
);

CREATE TABLE runs.llm_calls (
  llm_call_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL,
  run_id         uuid,
  step_id        uuid,
  purpose        text NOT NULL,
  model          text NOT NULL,
  prompt_version text NOT NULL,
  input_tokens   int,
  output_tokens  int,
  latency_ms     int,
  trace_id       text,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX llm_calls_tenant_time_idx ON runs.llm_calls (tenant_id, created_at DESC);

-- Per-tenant behavior lives here, owned by the runs service. Identity (tenants, users) lives in the ingest schema.
CREATE TABLE runs.tenant_settings (
  tenant_id                uuid PRIMARY KEY,
  approval_variance_percent numeric(5,2) NOT NULL DEFAULT 5.00,
  policy_set               text NOT NULL DEFAULT 'default',
  adapter                  jsonb NOT NULL DEFAULT '{}'::jsonb,
  settings                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at               timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER tenant_settings_touch BEFORE UPDATE ON runs.tenant_settings
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Append-only enforcement, on top of simply not granting UPDATE or DELETE.
CREATE TRIGGER audit_log_append_only BEFORE UPDATE OR DELETE ON runs.audit_log
  FOR EACH ROW EXECUTE FUNCTION public.forbid_mutation();
CREATE TRIGGER audit_log_no_truncate BEFORE TRUNCATE ON runs.audit_log
  FOR EACH STATEMENT EXECUTE FUNCTION public.forbid_mutation();
CREATE TRIGGER approvals_append_only BEFORE UPDATE OR DELETE ON runs.approvals
  FOR EACH ROW EXECUTE FUNCTION public.forbid_mutation();

-- Row-Level Security: a row is visible and writable only when its tenant matches app.tenant_id.
-- No tenant set (or an empty value) means no rows. NULLIF avoids a cast error on an empty setting.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['runs','run_steps','tool_calls','approvals','drafts','audit_log',
                           'idempotency_keys','llm_calls','tenant_settings'] LOOP
    EXECUTE format('ALTER TABLE runs.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE runs.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format($p$CREATE POLICY tenant_isolation ON runs.%I
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)$p$, t);
  END LOOP;
END $$;

-- Least privilege: the service can read and write what it needs, nothing more.
GRANT SELECT, INSERT, UPDATE ON runs.runs, runs.run_steps, runs.drafts, runs.tenant_settings TO runs_svc;
GRANT SELECT, INSERT ON runs.tool_calls, runs.approvals, runs.audit_log, runs.llm_calls TO runs_svc;
GRANT SELECT, INSERT, DELETE ON runs.idempotency_keys TO runs_svc;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA runs TO runs_svc;
