# 0006. Invoice versions are immutable: model output and human corrections are separate rows

**Status:** Accepted (contracts and schema v0.2)

## Context
Reviewers will correct extraction mistakes, and we need both an audit trail and training data.

## Decision
Each extraction creates invoice version 1 (source 'model', with model name and prompt version). Each accepted correction creates a new version (source 'human', with the user). Versions are never updated. The current invoice is the latest version.

## Why
Nothing is lost, every change is attributable, and the model-versus-human differences become a labeled dataset for fine-tuning and evaluation.

## Trade-offs
More rows and a slightly more complex 'latest version' query.

## Interview talking point
How do you turn human review into a feedback loop? Answer: immutable versions, then corrections feed evaluation and fine-tuning data.

## Revisit when
Storage grows large enough to need archiving.
