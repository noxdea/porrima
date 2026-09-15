# frozen_string_literal: true

module Porrima
  module Merge
    Change = Struct.new(:start, :finish, :replacement, :side, keyword_init: true)
    Conflict = Struct.new(:base_start, :base_count, :base, :ours, :theirs, keyword_init: true)
    Region = Struct.new(:conflict, :output_start, :output_count, :index, keyword_init: true)
    RESOLUTION_CHOICES = %i[ours theirs base ours_then_theirs theirs_then_ours].freeze
    private_constant :RESOLUTION_CHOICES

    class Result
      attr_reader :sections, :conflicts

      def initialize(sections)
        raise ArgumentError, "sections must be an array" unless sections.is_a?(Array)
        @sections = sections.map { |section| snapshot(section) }.freeze
        @conflicts = @sections.grep(Conflict).freeze
        freeze
      end

      def clean? = conflicts.empty?
      def resolved? = conflicts.empty?

      def regions
        output_line = conflict_index = 0
        sections.each_with_object([]) do |section, regions|
          unless section.is_a?(Conflict)
            output_line += section.count("\n")
            next
          end

          marked = +""
          Merge.send(:append_conflict_text, marked, section, :merge, ["ours", "base", "theirs"])
          output_count = marked.count("\n")
          regions << Region.new(conflict: section, output_start: output_line,
            output_count: output_count, index: conflict_index).freeze
          output_line += output_count
          conflict_index += 1
        end.freeze
      end

      private

      def snapshot(section)
        return section.dup.freeze if section.is_a?(String)
        raise ArgumentError, "sections must contain strings or conflicts" unless section.is_a?(Conflict)
        unless section.base_start.is_a?(Integer) && section.base_start >= 0 &&
            section.base_count.is_a?(Integer) && section.base_count >= 0 &&
            [section.base, section.ours, section.theirs].all?(String)
          raise ArgumentError, "invalid conflict"
        end

        Conflict.new(base_start: section.base_start, base_count: section.base_count,
          base: section.base.dup.freeze, ours: section.ours.dup.freeze,
          theirs: section.theirs.dup.freeze).freeze
      end
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
        append_conflict_text(output, section, style, labels)
      end
    end

    def resolve(result, index, choice)
      validate_result(result)
      unless index.is_a?(Integer) && index.between?(0, result.conflicts.length - 1)
        raise ArgumentError, "index must identify a conflict"
      end
      validate_choice(choice)
      conflict = result.conflicts[index]
      Result.new(result.sections.map { |section| section.equal?(conflict) ? resolution_text(conflict, choice) : section })
    end

    def resolve_all(result, choice)
      validate_result(result)
      validate_choice(choice)
      Result.new(result.sections.map { |section| section.is_a?(Conflict) ? resolution_text(section, choice) : section })
    end

    def to_resolved_text(result)
      validate_result(result)
      raise ArgumentError, "merge result has unresolved conflicts" unless result.resolved?
      result.sections.join
    end

    def conflict_inline(conflict)
      unless conflict.is_a?(Conflict) && [conflict.ours, conflict.theirs].all?(String)
        raise ArgumentError, "conflict must contain ours and theirs text"
      end
      ours, theirs = Inline.refine(conflict.ours, conflict.theirs)
      {ours: ours, theirs: theirs}
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

    def append_conflict_text(output, conflict, style, labels)
      output << "<<<<<<< #{labels[0]}\n"
      append_marked_text(output, conflict.ours)
      if style == :diff3
        output << "||||||| #{labels[1]}\n"
        append_marked_text(output, conflict.base)
      end
      output << "=======\n"
      append_marked_text(output, conflict.theirs)
      output << ">>>>>>> #{labels[2]}\n"
    end
    private_class_method :append_conflict_text

    def validate_result(result)
      raise ArgumentError, "result must be a Porrima::Merge::Result" unless result.is_a?(Result)
    end
    private_class_method :validate_result

    def validate_choice(choice)
      valid = RESOLUTION_CHOICES.include?(choice) || choice.is_a?(String) ||
        (choice.is_a?(Array) && choice.all?(String))
      raise ArgumentError, "invalid resolution choice" unless valid
    end
    private_class_method :validate_choice

    def resolution_text(conflict, choice)
      case choice
      when :ours then conflict.ours
      when :theirs then conflict.theirs
      when :base then conflict.base
      when :ours_then_theirs then join_alternatives(conflict.ours, conflict.theirs)
      when :theirs_then_ours then join_alternatives(conflict.theirs, conflict.ours)
      when Array then choice.join
      else choice
      end
    end
    private_class_method :resolution_text

    def join_alternatives(first, second)
      return first + second if first.empty? || second.empty? || first.end_with?("\n")
      first + "\n" + second
    end
    private_class_method :join_alternatives
  end
end
