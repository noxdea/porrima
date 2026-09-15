# frozen_string_literal: true

require "diff/lcs"
require "porrima"

def median(samples = 5)
  values = Array.new(samples) do
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1_000
  end
  values.sort[values.length / 2]
end

before = Array.new(20_000) { |index| "line #{index}\n" }
after = before.dup
after[10_000] = "changed\n"
Porrima.edits(before, after)
Diff::LCS.sdiff(before, after)
porrima = median { Porrima.edits(before, after) }
comparison = median { Diff::LCS.sdiff(before, after) }

replaced_before = Array.new(20_000) { |index| "old #{index}\n" }
replaced_after = Array.new(20_000) { |index| "new #{index}\n" }
replacement = median { Porrima.edits(replaced_before, replaced_after) }

conflict = Porrima::Merge::Conflict.new(base_start: 1, base_count: 1,
  base: "base\n", ours: "ours\n", theirs: "theirs\n")
merge = Porrima::Merge::Result.new(Array.new(500) { |index| ["line #{index}\n", conflict] }.flatten)
regions = median { merge.regions }
resolution = median { Porrima::Merge.resolve_all(merge, :ours) }

puts "20k lines / one edit: Porrima #{porrima.round(3)} ms, diff-lcs #{comparison.round(3)} ms"
puts "20k lines / complete replacement: Porrima #{replacement.round(3)} ms"
puts "500 merge conflicts / regions: #{regions.round(3)} ms, resolve all: #{resolution.round(3)} ms"

if ARGV.include?("--assert") || ENV["BUDGET"] == "1"
  abort "Porrima exceeded diff-lcs median" if porrima > comparison
  abort "complete replacement exceeded 50 ms" if replacement >= 50
  abort "merge regions exceeded 20 ms" if regions >= 20
  abort "merge resolution exceeded 20 ms" if resolution >= 20
end
