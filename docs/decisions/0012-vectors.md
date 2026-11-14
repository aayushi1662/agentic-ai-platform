# 0012. Vectors: pgvector with an HNSW index, 384 dimensions, model name stored per chunk

**Status:** Accepted (contracts and schema v0.2)

## Context
RAG needs fast similarity search that respects tenants and can be re-embedded later.

## Decision
knowledge.policy_chunks stores a vector(384) embedding (matching the small BGE model we start with), the embedding_model name, and a generated tsvector for keyword search, with a GIN index and an HNSW index (cosine). Hybrid search merges both result lists. We filter by tenant. Known caveat: an approximate index plus a filter can return fewer than the requested number of rows; raise the HNSW search setting or use iterative scans if your pgvector version supports them (check the pgvector documentation).

## Why
One database serves relational data, keyword search, and vector search, which keeps the system simple to run and test.

## Trade-offs
A different embedding dimension needs a new column and a re-embed, not an in-place edit.

## Interview talking point
How do you combine keyword and vector search, and what are the limits of filtered ANN?

## Revisit when
A dedicated vector database is justified by scale.
