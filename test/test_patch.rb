# frozen_string_literal: true

require_relative "test_helper"

class PatchTest < Minitest::Test
  def test_unified_parse_apply_and_revert_round_trip
    before = "one\r\ntwo\r\nlast"
    after = "one\r\nchanged\r\nlast\r\nnew"
    file = Porrima::Patch.parse(Porrima.unified(before, after, old_name: "a/sample", new_name: "b/sample", context: 1)).first
    assert_equal "a/sample", file.old_name
    assert_equal "b/sample", file.new_name
    assert file.applies?(before)
    assert_equal after, file.apply(before)
    assert_equal before, file.revert(after)
    refute file.applies?("stale\n")
  end

  def test_new_and_deleted_files
    created = Porrima::Patch.parse(Porrima.unified("", "new\n", old_name: "/dev/null", new_name: "b/new", context: 0)).first
    assert_equal "new\n", created.apply("")
    deleted = Porrima::Patch.parse(Porrima.unified("old\n", "", old_name: "a/old", new_name: "/dev/null", context: 0)).first
    assert_equal "", deleted.apply("old\n")
  end

  def test_multiple_files_and_omitted_counts
    patch = <<~PATCH
      --- a/one
      +++ b/one
      @@ -1 +1 @@
      -old
      +new
      --- a/two
      +++ b/two
      @@ -0,0 +1 @@
      +created
    PATCH
    files = Porrima::Patch.parse(patch)
    assert_equal 2, files.length
    assert_equal "new\n", files[0].apply("old\n")
    assert_equal "created\n", files[1].apply("")
  end

  def test_malformed_input_raises_patch_error
    ["not a patch\n", "--- old\n", "--- old\n+++ new\n@@ broken\n", "--- old\n+++ new\n@@ -1 +1 @@\n-old\n"].each do |patch|
      assert_raises(Porrima::PatchError) { Porrima::Patch.parse(patch) }
    end
  end
end
