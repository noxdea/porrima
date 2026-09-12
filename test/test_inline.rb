# frozen_string_literal: true

require_relative "test_helper"

class InlineTest < Minitest::Test
  def test_word_refinement_preserves_both_inputs
    old_spans, new_spans = Porrima::Inline.refine("hello old world", "hello new world")
    assert_equal "hello old world", old_spans.map(&:text).join
    assert_equal "hello new world", new_spans.map(&:text).join
    assert_equal %i[equal delete equal], old_spans.map(&:kind)
    assert_equal %i[equal insert equal], new_spans.map(&:kind)
  end

  def test_character_refinement_keeps_grapheme_clusters_whole
    old_spans, new_spans = Porrima::Inline.refine("e\u0301x", "e\u0301y", granularity: :char)
    assert_equal "e\u0301", old_spans.first.text
    assert_equal "e\u0301", new_spans.first.text
    assert_equal "x", old_spans.last.text
    assert_equal "y", new_spans.last.text
  end

  def test_refine_row_accepts_missing_side
    row = Porrima::Row.new(kind: :added, old_line: nil, new_line: 1, old_text: nil, new_text: "new")
    old_spans, new_spans = Porrima::Inline.refine_row(row)
    assert_empty old_spans
    assert_equal [{kind: :insert, text: "new"}], new_spans.map(&:to_h)
  end

  def test_token_limit_falls_back_to_whole_text_replacement
    old_text = "old " * 1_001
    new_text = "new " * 1_001
    old_spans, new_spans = Porrima::Inline.refine(old_text, new_text)
    assert_equal [{kind: :delete, text: old_text}], old_spans.map(&:to_h)
    assert_equal [{kind: :insert, text: new_text}], new_spans.map(&:to_h)
  end

  def test_invalid_granularity_is_rejected
    assert_raises(ArgumentError) { Porrima::Inline.refine("a", "b", granularity: :line) }
  end
end
