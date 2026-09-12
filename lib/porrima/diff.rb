# frozen_string_literal: true

module Porrima
  class Diff
    def initialize(before, after, context: 3, budget: nil)
      @before = snapshot(before)
      @after = snapshot(after)
      @context = context
      @budget = budget
      @memo = {}
      freeze
    end

    def edits = @memo[:edits] ||= Porrima.edits(@before, @after, budget: @budget).each(&:freeze).freeze

    def hunks
      @memo[:hunks] ||= Porrima.hunks(@before, @after, context: @context, budget: @budget).each do |hunk|
        hunk.edits.each(&:freeze).freeze
        hunk.freeze
      end.freeze
    end

    def marks = @memo[:marks] ||= build_marks.freeze
    def rows = @memo[:rows] ||= build_rows.freeze

    def stat
      @memo[:stat] ||= Stat.new(insertions: edits.count { |edit| edit.kind == :insert },
        deletions: edits.count { |edit| edit.kind == :delete }, hunks: hunks.length).freeze
    end

    def hunk_at(new_line:)
      left = 0
      right = hunks.length - 1
      while left <= right
        middle = (left + right) / 2
        hunk = hunks[middle]
        first = [hunk.new_start, 1].max
        last = [hunk.new_start + hunk.new_count - 1, hunk.new_start, 1].max
        return hunk if new_line.between?(first, last)
        new_line < first ? right = middle - 1 : left = middle + 1
      end
      nil
    end

    def mark_at(new_line:)
      marks.find do |mark|
        mark.kind == :removed ? new_line == mark.new_line : new_line.between?(mark.new_line, mark.new_line + mark.count - 1)
      end
    end

    def empty? = Porrima.identical?(@before, @after)

    def to_unified(old_name: "a/file", new_name: "b/file")
      Porrima.unified(@before, @after, old_name: old_name, new_name: new_name, context: @context, budget: @budget)
    end

    def to_h
      {version: 1, edits: edits.map(&:to_h), hunks: hunks.map { |hunk| hunk.to_h.merge(edits: hunk.edits.map(&:to_h)) },
       stat: stat.to_h, marks: marks.map(&:to_h), rows: rows.map(&:to_h)}
    end

    private

    def snapshot(value)
      return value.dup.freeze if value.is_a?(String)
      value.map { |item| item.dup.freeze }.freeze
    end

    def build_marks
      Porrima.hunks(@before, @after, context: 0, budget: @budget).map do |hunk|
        insertions = hunk.edits.count { |edit| edit.kind == :insert }
        deletions = hunk.edits.count { |edit| edit.kind == :delete }
        kind = insertions.positive? ? (deletions.positive? ? :modified : :added) : :removed
        Mark.new(new_line: hunk.new_start, kind: kind, count: insertions.positive? ? insertions : deletions).freeze
      end
    end

    def build_rows
      result = []
      index = 0
      while index < edits.length
        edit = edits[index]
        if edit.kind == :equal
          result << Row.new(kind: :equal, old_line: edit.old_line, new_line: edit.new_line, old_text: edit.text, new_text: edit.text).freeze
          index += 1
          next
        end
        changed = []
        while index < edits.length && edits[index].kind != :equal
          changed << edits[index]
          index += 1
        end
        deleted = changed.select { |item| item.kind == :delete }
        inserted = changed.select { |item| item.kind == :insert }
        [deleted.length, inserted.length].max.times do |offset|
          old, new = deleted[offset], inserted[offset]
          kind = old && new ? :modified : old ? :removed : :added
          result << Row.new(kind: kind, old_line: old&.old_line, new_line: new&.new_line,
            old_text: old&.text, new_text: new&.text).freeze
        end
      end
      result
    end
  end
end
