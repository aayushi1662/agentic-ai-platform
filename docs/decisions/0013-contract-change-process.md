# 0013. Contract change process

**Status:** Accepted (contracts and schema v0.2)

## Context
Two people on separate laptops must never drift apart silently.

## Decision
Contracts live in /contracts (Pydantic models plus fixtures). No one edits them alone. A change needs a pull request that updates the model, the fixtures, and the tests, approved by both teammates, plus a decision-log entry. CI validates every fixture against its model, so drift fails the build. The proposal template is in the shared kickoff prompt.

## Why
Contracts are the only thing the two halves share, so they get the strictest review.

## Trade-offs
Slower changes to shared interfaces, on purpose.

## Interview talking point
How do you stop two teams from breaking each other's API?

## Revisit when
Never.
