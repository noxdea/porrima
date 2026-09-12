# frozen_string_literal: true

require_relative "test_helper"

class DiffTest < Minitest::Test
  def test_result_collects_edits_hunks_stat_and_unified_output
    diff = Porrima.diff("one\ntwo\nthree\n", "one\nchanged\nthree\nnew\n", context: 0)
    refute diff.empty?
    assert_equal({insertions: 2, deletions: 1, hunks: 2}, diff.stat.to_h)
    assert_equal 2, diff.hunks.length
    assert_same diff.hunks.first, diff.hunk_at(new_line: 2)
    assert_same diff.hunks.last, diff.hunk_at(new_line: 4)
    assert_nil diff.hunk_at(new_line: 3)
    assert_equal Porrima.unified("one\ntwo\nthree\n", "one\nchanged\nthree\nnew\n", context: 0), diff.to_unified
    assert_equal 1, diff.to_h[:version]
  end

  def test_marks_cover_insert_modify_remove_and_boundaries
    assert_equal [{new_line: 1, kind: :added, count: 1}], Porrima.diff("", "new\n").marks.map(&:to_h)
    assert_equal [{new_line: 2, kind: :added, count: 1}], Porrima.diff("one\n", "one\ntwo\n").marks.map(&:to_h)
    assert_equal [{new_line: 0, kind: :removed, count: 2}], Porrima.diff("one\ntwo\n", "").marks.map(&:to_h)
    diff = Porrima.diff("one\ntwo\n", "one\nchanged\nextra\n")
    assert_equal [{new_line: 2, kind: :modified, count: 2}], diff.marks.map(&:to_h)
    assert_same diff.marks.first, diff.mark_at(new_line: 3)
    assert_nil diff.mark_at(new_line: 1)
  end

  def test_rows_pair_changes_without_display_policy
    rows = Porrima.diff("same\none\ntwo\n", "same\nchanged\nextra\nmore\n").rows
    assert_equal %i[equal modified modified added], rows.map(&:kind)
    assert_equal ["one\n", "changed\n"], [rows[1].old_text, rows[1].new_text]
    assert_nil rows.last.old_text
    assert_equal "more\n", rows.last.new_text
  end

  def test_hunk_lookup_handles_deletion_anchors
    beginning = Porrima.diff("gone\nkeep\n", "keep\n", context: 0)
    assert_equal 0, beginning.marks.first.new_line
    assert_same beginning.hunks.first, beginning.hunk_at(new_line: 1)
    ending = Porrima.diff("keep\ngone\n", "keep\n", context: 0)
    assert_same ending.hunks.first, ending.hunk_at(new_line: 1)
  end

  def test_result_is_a_snapshot_with_frozen_collections
    before = +"old\n"
    diff = Porrima.diff(before, "new\n")
    before.replace("mutated\n")
    assert_equal "old\n", diff.hunks.first.old_text
    assert_predicate diff, :frozen?
    assert_predicate diff.edits, :frozen?
    assert_predicate diff.edits.first, :frozen?
  end
end
