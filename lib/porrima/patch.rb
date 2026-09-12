# frozen_string_literal: true

module Porrima
  module Patch
    FileDiff = Struct.new(:old_name, :new_name, :hunks, keyword_init: true) do
      def applies?(text)
        apply(text)
        true
      rescue PatchError
        false
      end

      def apply(text)
        hunks.reverse_each { |hunk| text = Porrima.apply(text, hunk) }
        text
      rescue ArgumentError => error
        raise PatchError, error.message
      end

      def revert(text)
        hunks.reverse_each { |hunk| text = Porrima.revert(text, hunk) }
        text
      rescue ArgumentError => error
        raise PatchError, error.message
      end
    end

    module_function

    def parse(text)
      lines = text.lines
      files = []
      index = 0
      while index < lines.length
        index += 1 while index < lines.length && !lines[index].start_with?("--- ")
        break if index == lines.length
        old_name = header_name(lines[index], "--- ")
        index += 1
        raise PatchError, "missing new file header" unless lines[index]&.start_with?("+++ ")
        new_name = header_name(lines[index], "+++ ")
        index += 1
        hunks = []
        while index < lines.length && lines[index].start_with?("@@ ")
          hunk, index = parse_hunk(lines, index)
          hunks << hunk
        end
        files << FileDiff.new(old_name: old_name, new_name: new_name, hunks: hunks)
      end
      raise PatchError, "malformed patch" if files.empty? && !text.empty?
      files
    rescue PatchError
      raise
    rescue StandardError => error
      raise PatchError, error.message
    end

    def header_name(line, prefix)
      line.delete_prefix(prefix).chomp.split("\t", 2).first
    end
    private_class_method :header_name

    def parse_hunk(lines, index)
      match = /\A@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/.match(lines[index])
      raise PatchError, "malformed hunk header" unless match
      old_start, old_count, new_start, new_count = match.captures.map.with_index { |value, offset| value ? value.to_i : [1, 3].include?(offset) ? 1 : nil }
      old_line = [old_start, 1].max
      new_line = [new_start, 1].max
      old_seen = new_seen = 0
      edits = []
      index += 1
      until old_seen == old_count && new_seen == new_count
        line = lines[index]
        raise PatchError, "truncated hunk" unless line && [" ", "-", "+"].include?(line[0])
        kind = {" " => :equal, "-" => :delete, "+" => :insert}.fetch(line[0])
        body = line[1..]
        index += 1
        if lines[index]&.start_with?("\\ No newline at end of file")
          body = body.delete_suffix("\n")
          index += 1
        end
        edits << Edit.new(kind: kind, old_line: old_line, new_line: new_line, text: body)
        unless kind == :insert
          old_line += 1
          old_seen += 1
        end
        unless kind == :delete
          new_line += 1
          new_seen += 1
        end
        raise PatchError, "hunk line count mismatch" if old_seen > old_count || new_seen > new_count
      end
      [Hunk.new(old_start: old_start, old_count: old_count, new_start: new_start, new_count: new_count, edits: edits), index]
    end
    private_class_method :parse_hunk
  end
end
