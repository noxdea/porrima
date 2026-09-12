# frozen_string_literal: true

require_relative "test_helper"

class MergeTest < Minitest::Test
  def test_one_sided_and_identical_changes_are_clean
    ours = Porrima::Merge.three_way(base: "one\ntwo\n", ours: "one\nchanged\n", theirs: "one\ntwo\n")
    assert_predicate ours, :clean?
    assert_equal "one\nchanged\n", Porrima::Merge.to_text(ours)
    same = Porrima::Merge.three_way(base: "old\n", ours: "new\n", theirs: "new\n")
    assert_predicate same, :clean?
    assert_equal "new\n", Porrima::Merge.to_text(same)
  end

  def test_nonoverlapping_changes_are_combined
    result = Porrima::Merge.three_way(base: "one\ntwo\nthree\n", ours: "ONE\ntwo\nthree\n", theirs: "one\ntwo\nTHREE\n")
    assert_predicate result, :clean?
    assert_equal "ONE\ntwo\nTHREE\n", Porrima::Merge.to_text(result)
  end

  def test_conflict_is_structured_and_serialized_separately
    result = Porrima::Merge.three_way(base: "old\n", ours: "ours", theirs: "theirs\n")
    refute_predicate result, :clean?
    assert_equal 1, result.conflicts.length
    assert_equal({base_start: 1, base_count: 1, base: "old\n", ours: "ours", theirs: "theirs\n"}, result.conflicts.first.to_h)
    assert_equal <<~TEXT, Porrima::Merge.to_text(result, labels: %w[local ancestor remote])
      <<<<<<< local
      ours
      ||||||| ancestor
      old
      =======
      theirs
      >>>>>>> remote
    TEXT
    assert_equal <<~TEXT, Porrima::Merge.to_text(result, style: :merge)
      <<<<<<< ours
      ours
      =======
      theirs
      >>>>>>> theirs
    TEXT
  end

  def test_empty_base_and_full_deletion
    conflict = Porrima::Merge.three_way(base: "", ours: "ours\n", theirs: "theirs\n")
    assert_equal 0, conflict.conflicts.first.base_start
    assert_equal 0, conflict.conflicts.first.base_count
    deleted = Porrima::Merge.three_way(base: "one\ntwo\n", ours: "", theirs: "one\nchanged\n")
    refute_predicate deleted, :clean?
  end

  def test_adjacent_conflicting_lines_share_one_conflict
    result = Porrima::Merge.three_way(base: "a\nb\n", ours: "x\nu\n", theirs: "y\nv\n")
    assert_equal 1, result.conflicts.length
    assert_equal 2, result.conflicts.first.base_count
  end

  def test_invalid_serializer_options_are_rejected
    result = Porrima::Merge.three_way(base: "", ours: "", theirs: "")
    assert_raises(ArgumentError) { Porrima::Merge.to_text(result, style: :colored) }
    assert_raises(ArgumentError) { Porrima::Merge.to_text(result, labels: ["ours"]) }
  end
end
