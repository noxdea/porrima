# frozen_string_literal: true

require_relative "porrima/version"
require_relative "porrima/errors"
require_relative "porrima/edit"
require_relative "porrima/budget"
require_relative "porrima/myers"
require_relative "porrima/hunks"
require_relative "porrima/unified"
require_relative "porrima/diff"
require_relative "porrima/patch"
require_relative "porrima/inline"
require_relative "porrima/merge"

module Porrima
  module_function

  def diff(before, after, context: 3, budget: nil) = Diff.new(before, after, context: context, budget: budget)

  def edits(before, after, budget: nil)
    left = before.is_a?(String) ? before.lines : before
    right = after.is_a?(String) ? after.lines : after
    if (budget || Budget::NONE).exceeded?(left, right)
      return numbered(left.map { |line| [:delete, line] } + right.map { |line| [:insert, line] })
    end

    prefix = 0
    prefix += 1 while prefix < left.length && prefix < right.length && left[prefix] == right[prefix]
    suffix = 0
    suffix += 1 while suffix < left.length - prefix && suffix < right.length - prefix && left[-suffix - 1] == right[-suffix - 1]
    a = left.slice(prefix, left.length - prefix - suffix)
    b = right.slice(prefix, right.length - prefix - suffix)
    middle = script(a, b)
    pairs = left.first(prefix).map { |line| [:equal, line] } + middle + (suffix.zero? ? [] : left.last(suffix).map { |line| [:equal, line] })
    numbered(pairs)
  end

  def revert(text, hunk)
    replace_hunk(text, hunk.new_start, hunk.new_count, hunk.new_text, hunk.old_text)
  end

  def apply(text, hunk)
    replace_hunk(text, hunk.old_start, hunk.old_count, hunk.old_text, hunk.new_text)
  end

  def identical?(before, after) = before == after

  def numbered(pairs)
    old_line = new_line = 1
    pairs.map do |kind, text|
      edit = Edit.new(kind: kind, old_line: old_line, new_line: new_line, text: text)
      old_line += 1 unless kind == :insert
      new_line += 1 unless kind == :delete
      edit
    end
  end
  private_class_method :numbered

  def replace_hunk(text, start_line, count, expected, replacement)
    lines = text.lines
    start = count.zero? ? start_line : start_line - 1
    raise ArgumentError, "hunk no longer applies" unless lines.slice(start, count)&.join == expected
    lines[start, count] = replacement.lines
    lines.join
  end
  private_class_method :replace_hunk
end
