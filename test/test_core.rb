# frozen_string_literal: true

require_relative "test_helper"

class CoreTest < Minitest::Test
  def test_apply_and_revert
    hunk = Porrima.hunks("one\ntwo\n", "one\nchanged\n", context: 0).first
    assert_equal "one\nchanged\n", Porrima.apply("one\ntwo\n", hunk)
    assert_equal "one\ntwo\n", Porrima.revert("one\nchanged\n", hunk)
    assert_raises(ArgumentError) { Porrima.apply("stale\n", hunk) }
  end

  def test_budget_replaces_or_raises
    replace = Porrima::Budget.new(max_lines: 1, on_exceeded: :replace)
    assert_equal %i[delete insert], Porrima.edits("old\n", "new\n", budget: replace).map(&:kind)
    strict = Porrima::Budget.new(max_bytes: 1, on_exceeded: :raise)
    assert_raises(Porrima::BudgetExceeded) { Porrima.edits("old", "new", budget: strict) }
  end
end
