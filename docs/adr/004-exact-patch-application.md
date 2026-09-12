# ADR 004: Apply patches without fuzz

- Status: Accepted
- Date: 2026-09-12

## Context

Searching near a hunk can apply a patch after surrounding text changes, but a
heuristic match can also modify the wrong location without an unambiguous rule.

## Decision

Require the old hunk text to match exactly at its declared position. Reject a
stale patch instead of searching nearby.

## Consequences

Application is deterministic and cannot silently choose a nearby match. A
caller needing fuzzy application must explicitly provide and own that policy.
