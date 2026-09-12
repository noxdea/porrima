# ADR 003: Exclude display policy

- Status: Accepted
- Date: 2026-09-12

## Context

Color, width, truncation, icons, and scrolling depend on the caller's terminal
or interface. Unified patches and conflict markers are exchange formats rather
than presentation choices.

## Decision

Return marks, paired rows, spans, and interoperable text formats without ANSI
color, layout, or truncation.

## Consequences

Callers can present the same result in different interfaces without undoing
library formatting. They must supply their own rendering policy.
