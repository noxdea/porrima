# ADR 001: Keep the runtime dependency-free

- Status: Accepted
- Date: 2026-09-12

## Context

Porrima is a low-level text component used in latency-sensitive and packaged
applications. A diff dependency could reduce local code but would add version,
installation, and behavior constraints to every caller.

## Decision

Use the Ruby standard library only at runtime and enforce an empty runtime
dependency list in CI.

## Consequences

Installation remains portable and predictable. Porrima owns its diff behavior
and maintenance; revisit this if a dependency provides the same compatibility,
linear-space behavior, and portability with less maintenance.
