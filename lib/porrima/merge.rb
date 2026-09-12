# frozen_string_literal: true

module Porrima
  module Merge
    Change = Struct.new(:start, :finish, :replacement, :side, keyword_init: true)
    Conflict = Struct.new(:base_start, :base_count, :base, :ours, :theirs, keyword_init: true)

    class Result
      attr_reader :sections, :conflicts

      def initialize(sections)
        @sections = sections.freeze
        @conflicts = sections.grep(Conflict).freeze
        freeze
      end

      def clean? = conflicts.empty?
    end

    module_function

    def three_way(base:, ours:, theirs:)
      return Result.new([ours]) if ours == theirs || theirs == base
      return Result.new([theirs]) if ours == base

      base_lines = lines(base)
      changes = side_changes(base, ours, :ours) + side_changes(base, theirs, :theirs)
      changes.sort_by! { |change| [change.start, change.finish] }
      sections = []
      cursor = index = 0
      while index < changes.length
        cluster = [changes[index]]
        index += 1
        while index < changes.length && cluster.any? { |change| overlap?(change, changes[index]) }
          cluster << changes[index]
          index += 1
        end
        first = cluster.map(&:start).min
        last = cluster.map(&:finish).max
        append_text(sections, base_lines[cursor...first].join)
        ours_changes = cluster.select { |change| change.side == :ours }
        theirs_changes = cluster.select { |change| change.side == :theirs }
        base_text = base_lines[first...last].join
        ours_text = project(base_lines, first, last, ours_changes)
        theirs_text = project(base_lines, first, last, theirs_changes)
        if ours_changes.empty? || theirs_changes.empty? || ours_text == theirs_text
          append_text(sections, ours_changes.empty? ? theirs_text : ours_text)
        elsif ours_text == base_text || theirs_text == base_text
          append_text(sections, ours_text == base_text ? theirs_text : ours_text)
        else
          append_conflict(sections, Conflict.new(base_start: first == last ? first : first + 1,
            base_count: last - first, base: base_text, ours: ours_text, theirs: theirs_text).freeze)
        end
        cursor = last
      end
      append_text(sections, base_lines[cursor..].join)
      Result.new(sections)
    end

    def to_text(result, style: :diff3, labels: ["ours", "base", "theirs"])
      raise ArgumentError, "style must be :diff3 or :merge" unless %i[diff3 merge].include?(style)
      raise ArgumentError, "labels must contain ours, base, and theirs" unless labels.is_a?(Array) && labels.length == 3 && labels.all?(String)
      result.sections.each_with_object(+"") do |section, output|
        unless section.is_a?(Conflict)
          output << section
          next
        end
        output << "<<<<<<< #{labels[0]}\n"
        append_marked_text(output, section.ours)
        if style == :diff3
          output << "||||||| #{labels[1]}\n"
          append_marked_text(output, section.base)
        end
        output << "=======\n"
        append_marked_text(output, section.theirs)
        output << ">>>>>>> #{labels[2]}\n"
      end
    end

    def lines(text) = text.is_a?(String) ? text.lines : text
    private_class_method :lines

    def side_changes(base, side, name)
      Porrima.hunks(base, side, context: 0).map do |hunk|
        start = hunk.old_count.zero? ? hunk.old_start : hunk.old_start - 1
        Change.new(start: start, finish: start + hunk.old_count, replacement: hunk.new_text.lines, side: name)
      end
    end
    private_class_method :side_changes

    def overlap?(left, right)
      left_insert = left.start == left.finish
      right_insert = right.start == right.finish
      return left.start == right.start if left_insert && right_insert
      return right.start < left.finish && right.start > left.start if right_insert
      return left.start < right.finish && left.start > right.start if left_insert
      left.start < right.finish && right.start < left.finish
    end
    private_class_method :overlap?

    def project(base, first, last, changes)
      cursor = first
      changes.sort_by(&:start).each_with_object([]) do |change, output|
        output.concat(base[cursor...change.start])
        output.concat(change.replacement)
        cursor = change.finish
      end.concat(base[cursor...last]).join
    end
    private_class_method :project

    def append_text(sections, text)
      return if text.empty?
      sections.last.is_a?(String) ? sections.last << text : sections << +text
    end
    private_class_method :append_text

    def append_conflict(sections, conflict)
      previous = sections.last
      unless previous.is_a?(Conflict)
        sections << conflict
        return
      end
      sections[-1] = Conflict.new(base_start: previous.base_start, base_count: previous.base_count + conflict.base_count,
        base: previous.base + conflict.base, ours: previous.ours + conflict.ours, theirs: previous.theirs + conflict.theirs).freeze
    end
    private_class_method :append_conflict

    def append_marked_text(output, text)
      output << text
      output << "\n" unless text.empty? || text.end_with?("\n")
    end
    private_class_method :append_marked_text
  end
end
