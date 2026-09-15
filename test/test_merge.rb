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

  def test_regions_locate_conflict_markers_in_merge_output
    result = separated_conflicts
    lines = Porrima::Merge.to_text(result, style: :merge).lines

    assert_equal [
      {conflict: result.conflicts[0], output_start: 1, output_count: 5, index: 0},
      {conflict: result.conflicts[1], output_start: 7, output_count: 5, index: 1}
    ], result.regions.map(&:to_h)
    result.regions.each do |region|
      assert_equal "<<<<<<< ours\n", lines.fetch(region.output_start)
      assert_equal ">>>>>>> theirs\n", lines.fetch(region.output_start + region.output_count - 1)
    end
  end

  def test_adjacent_conflict_region_covers_one_combined_block
    result = Porrima::Merge.three_way(base: "a\nb\n", ours: "x\nu\n", theirs: "y\nv\n")

    assert_equal({conflict: result.conflicts.first, output_start: 0, output_count: 7, index: 0}, result.regions.first.to_h)
  end

  def test_resolve_supports_every_choice_without_changing_the_source
    result = Porrima::Merge.three_way(base: "head\nold\ntail\n", ours: "head\nours\ntail\n", theirs: "head\ntheirs\ntail\n")
    original = Porrima::Merge.to_text(result)
    expected = {
      ours: "head\nours\ntail\n",
      theirs: "head\ntheirs\ntail\n",
      base: "head\nold\ntail\n",
      ours_then_theirs: "head\nours\ntheirs\ntail\n",
      theirs_then_ours: "head\ntheirs\nours\ntail\n",
      "manual\n" => "head\nmanual\ntail\n",
      ["first\n", "second\n"] => "head\nfirst\nsecond\ntail\n"
    }

    expected.each do |choice, text|
      resolved = Porrima::Merge.resolve(result, 0, choice)
      assert_predicate resolved, :resolved?
      assert_equal text, Porrima::Merge.to_resolved_text(resolved)
    end
    refute_predicate result, :resolved?
    assert_equal original, Porrima::Merge.to_text(result)
  end

  def test_resolve_all_resolves_each_current_conflict
    result = separated_conflicts
    resolved = Porrima::Merge.resolve_all(result, :theirs)

    assert_equal "a\nB theirs\nc\nD theirs\ne\n", Porrima::Merge.to_resolved_text(resolved)
    assert_empty resolved.regions
    assert_equal 2, result.conflicts.length
  end

  def test_resolved_results_snapshot_mutable_input
    text = +"mutable\n"
    conflict = Porrima::Merge::Conflict.new(base_start: 1, base_count: 1,
      base: +"base\n", ours: +"ours\n", theirs: +"theirs\n")
    result = Porrima::Merge::Result.new([text, conflict])
    text << "changed\n"
    conflict.ours << "changed\n"

    assert_equal "mutable\n", result.sections.first
    assert_equal "ours\n", result.conflicts.first.ours
    assert_raises(FrozenError) { result.sections.first << "changed" }
    assert_raises(FrozenError) { result.conflicts.first.ours << "changed" }
    assert_raises(FrozenError) { result.conflicts.first.base_start = 2 }
  end

  def test_conflict_inline_reuses_inline_word_spans
    conflict = Porrima::Merge.three_way(base: "hello old\n", ours: "hello ours\n", theirs: "hello theirs\n").conflicts.first
    inline = Porrima::Merge.conflict_inline(conflict)

    assert_equal Porrima::Inline.refine(conflict.ours, conflict.theirs).first, inline.fetch(:ours)
    assert_equal Porrima::Inline.refine(conflict.ours, conflict.theirs).last, inline.fetch(:theirs)
  end

  def test_resolution_api_rejects_invalid_inputs
    result = Porrima::Merge.three_way(base: "old\n", ours: "ours\n", theirs: "theirs\n")

    [nil, Object.new].each { |value| assert_raises(ArgumentError) { Porrima::Merge.resolve(value, 0, :ours) } }
    [-1, 1, "0"].each { |index| assert_raises(ArgumentError) { Porrima::Merge.resolve(result, index, :ours) } }
    [:both, ["valid", 1], Object.new].each { |choice| assert_raises(ArgumentError) { Porrima::Merge.resolve(result, 0, choice) } }
    assert_raises(ArgumentError) { Porrima::Merge.resolve_all(result, :both) }
    assert_raises(ArgumentError) { Porrima::Merge.to_resolved_text(result) }
    assert_raises(ArgumentError) { Porrima::Merge.conflict_inline(Object.new) }
    assert_raises(ArgumentError) { Porrima::Merge::Result.new([Object.new]) }
  end

  def test_existing_merge_serialization_matches_byte_golden
    result = separated_conflicts

    assert_equal File.binread(File.join(__dir__, "fixtures", "merge_diff3.txt")), Porrima::Merge.to_text(result)
    assert_equal File.binread(File.join(__dir__, "fixtures", "merge_markers.txt")), Porrima::Merge.to_text(result, style: :merge)
  end

  def test_invalid_serializer_options_are_rejected
    result = Porrima::Merge.three_way(base: "", ours: "", theirs: "")
    assert_raises(ArgumentError) { Porrima::Merge.to_text(result, style: :colored) }
    assert_raises(ArgumentError) { Porrima::Merge.to_text(result, labels: ["ours"]) }
  end

  private

  def separated_conflicts
    Porrima::Merge.three_way(
      base: "a\nb\nc\nd\ne\n",
      ours: "a\nB ours\nc\nD ours\ne\n",
      theirs: "a\nB theirs\nc\nD theirs\ne\n"
    )
  end
end
