# frozen_string_literal: true

module Porrima
  Edit = Struct.new(:kind, :old_line, :new_line, :text, keyword_init: true)
  Hunk = Struct.new(:old_start, :old_count, :new_start, :new_count, :edits, keyword_init: true) do
    def old_text = edits.reject { |edit| edit.kind == :insert }.map(&:text).join
    def new_text = edits.reject { |edit| edit.kind == :delete }.map(&:text).join
  end
  Mark = Struct.new(:new_line, :kind, :count, keyword_init: true)
  Row = Struct.new(:kind, :old_line, :new_line, :old_text, :new_text, keyword_init: true)
  Stat = Struct.new(:insertions, :deletions, :hunks, keyword_init: true)
  Span = Struct.new(:kind, :text, keyword_init: true)
end
