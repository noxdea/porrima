# ADR 005: Use zero-based merge output regions

- Status: Accepted
- Date: 2026-09-15

## Context

Merge conflicts already carry one-based Git-style base positions, with zero for
an insertion into an empty base. Conflict resolution UIs instead address rows
in an output buffer, where zero-based positions avoid repeated conversion.

## Decision

`Merge::Region#output_start` is a zero-based row in the exact text produced by
`Merge.to_text(style: :merge)`. `output_count` covers the complete marker block,
including both alternatives and all marker rows.

## Consequences

Callers can pass regions directly to zero-based editor buffers. Consumers that
display one-based line numbers must add one at the presentation boundary.
