# frozen_string_literal: true

module Porrima
  module Structured
    CellChange = Struct.new(:kind, :row, :column, :before, :after, keyword_init: true)
    SlideChange = Struct.new(:kind, :old_index, :new_index, :before, :after, keyword_init: true)

    module_function

    # Coordinates are zero-based, matching the sparse sheet's each_in points.
    def sheet(before, after)
      old_cells = cells(before)
      new_cells = cells(after)
      (old_cells.keys | new_cells.keys).sort.filter_map do |row, column|
        position = [row, column]
        old_present = old_cells.key?(position)
        new_present = new_cells.key?(position)
        old_value = old_cells[position]
        new_value = new_cells[position]
        next if old_present && new_present && old_value == new_value

        kind = old_present ? (new_present ? :modified : :removed) : :added
        CellChange.new(kind: kind, row: row, column: column, before: old_value, after: new_value).freeze
      end.freeze
    end

    # The block selects the content used to align slides. Without it, values
    # themselves are compared. Positions are zero-based, matching Deck#slide.
    def slides(before, after, &identity)
      identity ||= ->(slide) { slide }
      ids = {}
      old_ids = slide_ids(before, ids, identity)
      new_ids = slide_ids(after, ids, identity)
      Porrima.diff(old_ids, new_ids).rows.filter_map do |row|
        next if row.kind == :equal

        old_index = row.old_line && row.old_line - 1
        new_index = row.new_line && row.new_line - 1
        SlideChange.new(kind: row.kind, old_index: old_index, new_index: new_index,
          before: old_index && before[old_index], after: new_index && after[new_index]).freeze
      end.freeze
    end

    def cells(sheet)
      entries = {}
      return entries if sheet.row_count.zero? || sheet.column_count.zero?

      sheet.each_in(0, 0, sheet.row_count - 1, sheet.column_count - 1) do |point, value|
        entries[[point.row, point.column]] = value
      end
      entries
    end
    private_class_method :cells

    def slide_ids(slides, ids, identity)
      slides.map { |slide| ids[identity.call(slide)] ||= ids.length.to_s }
    end
    private_class_method :slide_ids
  end
end
