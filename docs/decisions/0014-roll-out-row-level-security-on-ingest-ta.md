# 0014. Roll out Row-Level Security on ingest tables in Week 8, not Week 1

**Status:** Accepted (contracts and schema v0.2)

## Context
Django's ORM and connection handling make RLS the riskiest part of Person A's early work.

## Decision
From Week 1, ingest code filters by tenant in the application layer (a manager or queryset that always applies tenant_id) and has tenant-isolation tests. In Week 8 we enable RLS on the ingest tables too, setting app.tenant_id with set_config in middleware inside an atomic request (ATOMIC_REQUESTS). Runs, knowledge, and erp have RLS from day one.

## Why
Person A is not blocked in the first weeks, and the stronger protection still lands before the demo.

## Trade-offs
For some weeks ingest relies on application-level filtering only.

## Interview talking point
How did you retrofit database-level isolation into an existing app?

## Revisit when
If Person A is comfortable earlier, enable RLS sooner.
