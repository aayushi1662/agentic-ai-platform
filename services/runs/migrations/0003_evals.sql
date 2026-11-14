-- Shared quality results, so the analytics page can show accuracy over time. Not tenant data: no RLS.

CREATE TABLE evals.eval_datasets (
  dataset_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  version     text NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (name, version)
);

CREATE TABLE evals.eval_runs (
  eval_run_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_id     uuid NOT NULL REFERENCES evals.eval_datasets (dataset_id),
  suite          text NOT NULL CHECK (suite IN ('extraction','retrieval','agent','safety')),
  git_sha        text,
  model          text,
  prompt_version text,
  config         jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at     timestamptz NOT NULL DEFAULT now(),
  finished_at    timestamptz
);
CREATE INDEX eval_runs_suite_time_idx ON evals.eval_runs (suite, started_at DESC);

CREATE TABLE evals.eval_results (
  eval_result_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  eval_run_id    uuid NOT NULL REFERENCES evals.eval_runs (eval_run_id) ON DELETE CASCADE,
  metric         text NOT NULL,
  value          numeric NOT NULL,
  details        jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX eval_results_run_idx ON evals.eval_results (eval_run_id, metric);

GRANT SELECT, INSERT, UPDATE ON evals.eval_datasets, evals.eval_runs, evals.eval_results TO eval_svc;
GRANT SELECT ON evals.eval_datasets, evals.eval_runs, evals.eval_results TO runs_svc;
