# Porrima

[![Gem version](https://img.shields.io/gem/v/porrima.svg)](https://rubygems.org/gems/porrima)
[![CI](https://github.com/noxdea/porrima/actions/workflows/main.yml/badge.svg)](https://github.com/noxdea/porrima/actions/workflows/main.yml)
[![CRuby 3.1+](https://img.shields.io/badge/CRuby-%3E%3D%203.1-cc342d.svg)](porrima.gemspec)
[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

Line, word, and three-way diff, patch, and merge in pure Ruby.

## Scope

Porrima computes from two or three texts. Its core never reads files, knows
nothing about Git, and has no runtime dependencies. Color, width, truncation,
caching, and other display policy belong to the caller. The CLI only connects
files to the library's interoperable formats.

## Installation

```sh
gem install porrima
```

## Quick start

```ruby
require "porrima"

result = Porrima.diff("one\ntwo\n", "one\nchanged\n", context: 1)
result.hunks
result.stat.to_h # => {insertions: 1, deletions: 1, hunks: 1}
result.marks
result.rows
result.to_unified(old_name: "a/example", new_name: "b/example")

old_spans, new_spans = Porrima::Inline.refine("hello old", "hello new")
patch = Porrima::Patch.parse(result.to_unified).first
patch.apply("one\ntwo\n")

merge = Porrima::Merge.three_way(base: "old\n", ours: "ours\n", theirs: "theirs\n")
Porrima::Merge.to_text(merge, style: :diff3)
```

`Porrima.edits`, `.hunks`, `.unified`, `.apply`, and `.revert` are available
as lower-level entry points. `Porrima::Budget` can replace an oversized input
as one block or raise `Porrima::BudgetExceeded`.

## Data model

- `Edit` is an equal, deleted, or inserted line with old and new positions.
- `Hunk` groups edits and exposes its exact old and new text.
- `Mark` locates an added, modified, or removed block on the new side.
- `Row` pairs old and new lines without presentation policy.
- `Span` describes equal, deleted, or inserted inline text.
- `Merge::Result` contains plain sections and structured conflicts; markers are
  only produced by `Merge.to_text`.

`Diff` snapshots its inputs and lazily memoizes these collections. Finish the
fields needed by another thread on the producing thread before handing the
instance across.

## CLI

```text
porrima [diff] [options] OLD NEW
porrima merge [options] BASE OURS THEIRS
porrima apply [options] PATCH [FILE]
```

Diff supports unified output, `--json`, `--quiet`, and `--max-bytes`. Merge
supports structured JSON or `diff3`/`merge` markers. Apply supports
`--reverse` and validation-only `--check`. Exit status is 0 for no
diff/conflict, 1 for a diff/conflict, and 2 for an error.

## Compatibility

Porrima requires CRuby 3.1 or newer. The line edit, hunk, unified output, and
revert behavior are byte-compatible with the original Canopus diff engine.
Public struct field names and order are part of the 0.1 contract.

## Development

```sh
bundle install
bundle exec rake
ruby tools/check_isolation.rb
bundle exec rbs -I sig validate
bundle exec rake bench:assert
gem build --strict porrima.gemspec
```

## Limits

- Comparison uses `String#==`; callers own encoding normalization.
- Patch application is exact and intentionally has no fuzz matching.
- Inline refinement treats over 2,000 combined tokens as a whole-text replacement.
- `Diff` memoization is not synchronized; complete it before cross-thread use.
- During 0.x releases, minor versions may contain breaking changes.

## License

Porrima is released under the [MIT License](LICENSE.txt).
