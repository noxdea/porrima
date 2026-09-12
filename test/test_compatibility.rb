# frozen_string_literal: true

require_relative "test_helper"
require_relative "fixtures/legacy_diff"

class CompatibilityTest < Minitest::Test
  def test_randomized_output_matches_canopus_snapshot
    random = Random.new(839)
    cases = Array.new(320) do
      vocabulary = Array.new(random.rand(1..50)) { |index| "word #{index}" }
      build = lambda do
        Array.new(random.rand(0..200)) do
          vocabulary.sample(random: random) + (random.rand(8).zero? ? "\r\n" : "\n")
        end.tap { |lines| lines[-1] = lines[-1].delete_suffix("\n").delete_suffix("\r") if lines.any? && random.rand(4).zero? }.join
      end
      [build.call, build.call]
    end
    cases.concat([["", ""], ["", "new"], ["old", ""], ["same\n", "same\n"], ["a\r\n", "a\n"],
      [Array.new(5_000) { |i| "#{i}\n" }.join, Array.new(5_000) { |i| "#{i == 2_500 ? 'changed' : i}\n" }.join]])

    cases.each do |before, after|
      assert_equal serialize(LegacyReference.edits(before, after)), serialize(Porrima.edits(before, after))
      [0, 1, 3, 10].each do |context|
        assert_equal serialize(LegacyReference.hunks(before, after, context: context)), serialize(Porrima.hunks(before, after, context: context))
        assert_equal LegacyReference.unified(before, after, context: context), Porrima.unified(before, after, context: context)
      end
    end
  end

  def test_fuzz_is_shortest_and_reversible
    random = Random.new(839)
    150.times do
      before = Array.new(random.rand(12)) { "#{random.rand(5)}\n" }
      after = Array.new(random.rand(12)) { "#{random.rand(5)}\n" }
      edits = Porrima.edits(before, after)
      assert_equal before, edits.reject { |edit| edit.kind == :insert }.map(&:text)
      assert_equal after, edits.reject { |edit| edit.kind == :delete }.map(&:text)
      lengths = Array.new(before.length + 1) { Array.new(after.length + 1, 0) }
      before.each_index { |i| after.each_index { |j| lengths[i + 1][j + 1] = before[i] == after[j] ? lengths[i][j] + 1 : [lengths[i][j + 1], lengths[i + 1][j]].max } }
      assert_equal before.length + after.length - 2 * lengths[-1][-1], edits.count { |edit| edit.kind != :equal }
      restored = after.join
      Porrima.hunks(before.join, after.join, context: 0).reverse_each { |hunk| restored = Porrima.revert(restored, hunk) }
      assert_equal before.join, restored
    end
  end

  def test_completely_replaced_large_file_skips_myers_search
    before = Array.new(20_000) { |index| "old #{index}\n" }
    after = Array.new(20_000) { |index| "new #{index}\n" }
    singleton = Porrima.singleton_class
    original = singleton.instance_method(:bisect)
    verbose, $VERBOSE = $VERBOSE, nil
    singleton.send(:define_method, :bisect) { |*| raise "disjoint lines do not need Myers search" }
    begin
      edits = Porrima.edits(before, after)
      assert_equal before, edits.select { |edit| edit.kind == :delete }.map(&:text)
      assert_equal after, edits.select { |edit| edit.kind == :insert }.map(&:text)
    ensure
      singleton.send(:define_method, :bisect, original)
      singleton.send(:private, :bisect)
      $VERBOSE = verbose
    end
  end

  private

  def serialize(value)
    case value
    when Array then value.map { |item| serialize(item) }
    when Struct then value.to_h.transform_values { |item| serialize(item) }
    else value
    end
  end
end
