# 0009. Audit log is append-only, enforced by privileges and by trigger

**Status:** Accepted (contracts and schema v0.2)

## Context
Auditors need proof that history was not edited.

## Decision
runs.audit_log and runs.approvals grant only SELECT and INSERT to the service role, and a trigger raises an error on UPDATE, DELETE, or TRUNCATE, even for the admin role. Optional prev_hash and row_hash columns exist so a hash chain can be added later without a migration.

## Why
Two independent layers (privileges and trigger) protect the record.

## Trade-offs
Corrections to the log are new rows, never edits. A superuser could still drop the trigger, so production would also ship logs to separate storage.

## Interview talking point
How would you make an audit log tamper-evident?

## Revisit when
Compliance requires external, write-once storage.
