# 0007. Workflow state: LangGraph checkpointer for resume, our own tables for the UI

**Status:** Accepted (contracts and schema v0.2)

## Context
A run can wait days for approval and must survive restarts, and the UI needs a clean history.

## Decision
The LangGraph Postgres checkpointer stores the workflow's internal state so a run can resume. Our runs, run_steps, tool_calls, approvals, and drafts tables are the read model for the UI and audit. We do not read the checkpointer's tables from other services. Check the current LangGraph documentation for the exact checkpointer setup call and how to place its tables in their own schema.

## Why
Separating resume state from business records means a LangGraph upgrade cannot break the UI or the audit trail.

## Trade-offs
Some data is stored twice in different shapes; the service must keep them consistent.

## Interview talking point
How does a run resume after the service restarts?

## Revisit when
LangGraph changes its persistence model.
