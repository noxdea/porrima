# frozen_string_literal: true

require_relative "test_helper"

class StructuredTest < Minitest::Test
  Point = Struct.new(:row, :column)
  Sheet = Struct.new(:entries, :row_count, :column_count) do
    def each_in(top, left, bottom, right)
      entries.each do |(row, column), value|
        yield Point.new(row, column), value if row.between?(top, bottom) && column.between?(left, right)
      end
    end
  end

  Slide = Struct.new(:layout, :content)

  def test_sheet_reports_sparse_cell_changes_without_scanning_empty_coordinates
    before = Sheet.new({[1, 4] => "old", [8, 2] => "removed", [9, 9] => "same"}, 10, 10)
    after = Sheet.new({[1, 4] => "new", [3, 0] => 42, [9, 9] => "same"}, 10, 10)

    changes = Porrima::Structured.sheet(before, after)
    assert_equal [[:modified, 1, 4, "old", "new"], [:added, 3, 0, nil, 42],
      [:removed, 8, 2, "removed", nil]], changes.map { |change| change.to_h.values_at(:kind, :row, :column, :before, :after) }
    assert changes.frozen?
    assert_empty Porrima::Structured.sheet(Sheet.new({}, 0, 0), Sheet.new({}, 0, 0))
  end

  def test_slides_align_equal_content_and_report_zero_based_positions
    old = [Slide.new(:title, "same"), Slide.new(:body, "old"), Slide.new(:body, "removed")]
    new = [Slide.new(:title, "same"), Slide.new(:body, "new")]

    changes = Porrima::Structured.slides(old, new) { |slide| [slide.layout, slide.content] }
    assert_equal [[:modified, 1, 1, old[1], new[1]], [:removed, 2, nil, old[2], nil]],
      changes.map { |change| change.to_h.values_at(:kind, :old_index, :new_index, :before, :after) }
    assert changes.frozen?
    assert_empty Porrima::Structured.slides(%w[same], %w[same])
  end
end
