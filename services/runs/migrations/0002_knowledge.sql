-- Owner: Person B. RAG data. Embedding dimension 384 matches the small BGE model we start with.
-- Each chunk stores which model produced its embedding, so we can re-embed later.
-- If you switch to a model with a different dimension, add a new column and re-embed; do not edit in place.

CREATE TABLE knowledge.policy_documents (
  policy_document_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  title              text NOT NULL,
  source_path        text NOT NULL,
  content_hash       text NOT NULL,
  version            int  NOT NULL DEFAULT 1,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, policy_document_id),
  UNIQUE (tenant_id, content_hash)
);

CREATE TABLE knowledge.policy_chunks (
  chunk_id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  policy_document_id uuid NOT NULL,
  chunk_index        int  NOT NULL,
  text               text NOT NULL,
  tsv                tsvector GENERATED ALWAYS AS (to_tsvector('english', text)) STORED,
  embedding          vector(384) NOT NULL,
  embedding_model    text NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (policy_document_id, chunk_index),
  FOREIGN KEY (tenant_id, policy_document_id)
    REFERENCES knowledge.policy_documents (tenant_id, policy_document_id) ON DELETE CASCADE
);
CREATE INDEX policy_chunks_tenant_idx ON knowledge.policy_chunks (tenant_id);
CREATE INDEX policy_chunks_tsv_idx ON knowledge.policy_chunks USING gin (tsv);
CREATE INDEX policy_chunks_embedding_idx ON knowledge.policy_chunks USING hnsw (embedding vector_cosine_ops);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['policy_documents','policy_chunks'] LOOP
    EXECUTE format('ALTER TABLE knowledge.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE knowledge.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format($p$CREATE POLICY tenant_isolation ON knowledge.%I
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)$p$, t);
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON knowledge.policy_documents, knowledge.policy_chunks TO runs_svc;
