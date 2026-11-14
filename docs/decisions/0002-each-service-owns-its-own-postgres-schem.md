# 0002. Each service owns its own Postgres schema; no cross-schema foreign keys

**Status:** Accepted (contracts and schema v0.2)

## Context
Two people build different services against one database and must not block each other with migration conflicts.

## Decision
Schemas: ingest (Person A), runs, knowledge, erp, evals (Person B / shared). Services reference each other only by ID and talk through APIs. Each service connects with its own database role that has only the rights it needs.

## Why
Separate ownership prevents migration collisions and keeps services replaceable. Least-privilege roles limit damage from a bug or a leaked credential.

## Trade-offs
No database-level referential integrity across services, so cross-service consistency is the application's job (for example, a run's document_id is validated through the API).

## Interview talking point
How do you keep microservices decoupled while sharing infrastructure?

## Revisit when
Services need to be deployed on separate databases (the schema boundaries already make that a small move).
