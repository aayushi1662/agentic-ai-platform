-- Database safety tests. Run after migrations:  make db-test
-- Everything happens inside one transaction that is rolled back, so no data is left behind.
-- Exits with an error (and a clear message) if any assertion fails.
\set ON_ERROR_STOP on
BEGIN;

-- Setup as the admin role (bypasses RLS): two tenants, one run each.
INSERT INTO runs.runs (run_id, tenant_id, document_id, status, invoice, vendor_name, invoice_number) VALUES
  ('aaaaaaaa-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', gen_random_uuid(), 'queued', '{}', 'Acme', 'INV-1'),
  ('bbbbbbbb-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', gen_random_uuid(), 'queued', '{}', 'Beta', 'INV-2');

SET LOCAL ROLE runs_svc;

-- 1. A tenant sees only its own rows.
SELECT set_config('app.tenant_id', '11111111-1111-4111-8111-111111111111', true);
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM runs.runs) = 1, 'tenant 1 should see exactly its own run';
  ASSERT (SELECT vendor_name FROM runs.runs) = 'Acme', 'tenant 1 saw the wrong run';
END $$;

-- 2. No tenant set means no rows (fail closed).
SELECT set_config('app.tenant_id', '', true);
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM runs.runs) = 0, 'no tenant set must return no rows';
END $$;

-- 3. Writing a row for another tenant is rejected.
SELECT set_config('app.tenant_id', '11111111-1111-4111-8111-111111111111', true);
DO $$ BEGIN
  BEGIN
    INSERT INTO runs.runs (tenant_id, document_id, invoice, vendor_name, invoice_number)
    VALUES ('22222222-2222-4222-8222-222222222222', gen_random_uuid(), '{}', 'Evil', 'INV-X');
    RAISE EXCEPTION 'cross-tenant insert was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;  -- RLS WITH CHECK violation
  END;
END $$;

-- 4. A child row cannot point at another tenant's run (composite foreign key).
DO $$ BEGIN
  BEGIN
    INSERT INTO runs.run_steps (tenant_id, run_id, seq, name, agent)
    VALUES ('11111111-1111-4111-8111-111111111111', 'bbbbbbbb-0000-4000-8000-000000000002', 1, 'x', 'checker');
    RAISE EXCEPTION 'cross-tenant child row was allowed';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
END $$;

-- 5. The audit log is append-only.
INSERT INTO runs.audit_log (tenant_id, actor, actor_type, action) VALUES
  ('11111111-1111-4111-8111-111111111111', 'tester', 'system', 'test');
DO $$ BEGIN
  BEGIN
    UPDATE runs.audit_log SET action = 'tampered';
    RAISE EXCEPTION 'audit log update was allowed';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    IF SQLERRM = 'audit log update was allowed' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM runs.audit_log;
    RAISE EXCEPTION 'audit log delete was allowed';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    IF SQLERRM = 'audit log delete was allowed' THEN RAISE; END IF;
  END;
END $$;

-- 6. Vector and keyword search work, and are tenant-filtered.
INSERT INTO knowledge.policy_documents (policy_document_id, tenant_id, title, source_path, content_hash)
VALUES ('cccccccc-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'Policy', 'p.md', 'h1');
INSERT INTO knowledge.policy_chunks (tenant_id, policy_document_id, chunk_index, text, embedding, embedding_model)
VALUES ('11111111-1111-4111-8111-111111111111', 'cccccccc-0000-4000-8000-000000000003', 0,
        'Invoices over the purchase order by more than 5 percent need manager approval.',
        array_fill(0.1::real, ARRAY[384])::vector, 'bge-small-en-v1.5');
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM knowledge.policy_chunks WHERE tsv @@ plainto_tsquery('english', 'manager approval')) = 1,
         'keyword search should find the chunk';
  ASSERT (SELECT count(*) FROM (SELECT 1 FROM knowledge.policy_chunks
          ORDER BY embedding <=> array_fill(0.1::real, ARRAY[384])::vector LIMIT 5) s) = 1,
         'vector search should find the chunk';
END $$;
SELECT set_config('app.tenant_id', '22222222-2222-4222-8222-222222222222', true);
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM knowledge.policy_chunks) = 0, 'tenant 2 must not see tenant 1 policy chunks';
END $$;

-- 7. Even the admin role cannot change or delete audit rows: the trigger blocks it.
RESET ROLE;
INSERT INTO runs.audit_log (tenant_id, actor, actor_type, action) VALUES
  ('11111111-1111-4111-8111-111111111111', 'admin-test', 'system', 'admin-check');
DO $$ BEGIN
  BEGIN
    UPDATE runs.audit_log SET action = 'tampered' WHERE actor = 'admin-test';
    RAISE EXCEPTION 'admin update of audit log was allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM = 'admin update of audit log was allowed' THEN RAISE; END IF;
  END;
END $$;

ROLLBACK;
\echo 'ALL DATABASE TESTS PASSED'
