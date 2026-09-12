# frozen_string_literal: true

module Porrima
  def hunks(before, after, context: 3, budget: nil)
    raise ArgumentError, "context must be nonnegative" unless context.is_a?(Integer) && context >= 0
    changes = edits(before, after, budget: budget)
    ranges = []
    changes.each_with_index do |edit, index|
      next if edit.kind == :equal
      first = [0, index - context].max
      last = [changes.length - 1, index + context].min
      if ranges.last && first <= ranges.last[1] + 1
        ranges.last[1] = last
      else
        ranges << [first, last]
      end
    end
    ranges.map do |first, last|
      items = changes[first..last]
      old_count = items.count { |edit| edit.kind != :insert }
      new_count = items.count { |edit| edit.kind != :delete }
      Hunk.new(old_start: items.first.old_line - (old_count.zero? ? 1 : 0), old_count: old_count,
        new_start: items.first.new_line - (new_count.zero? ? 1 : 0), new_count: new_count, edits: items)
    end
  end
  module_function :hunks
end
