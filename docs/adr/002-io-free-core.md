# ADR 002: Keep file I/O out of the core

- Status: Accepted
- Date: 2026-09-12

## Context

Text comparison is deterministic from its input strings, while paths, files,
and streams introduce environment and safety concerns.

## Decision

Core APIs accept text and return text or structured data. Only the CLI may use
file and stream APIs, with the boundary checked in CI.

## Consequences

The core is easy to embed and test. Applications must choose and read their
inputs themselves; revisit only if a universal I/O contract emerges.
