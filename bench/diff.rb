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

puts "20k lines / one edit: Porrima #{porrima.round(3)} ms, diff-lcs #{comparison.round(3)} ms"
puts "20k lines / complete replacement: Porrima #{replacement.round(3)} ms"

if ARGV.include?("--assert")
  abort "Porrima exceeded diff-lcs median" if porrima > comparison
  abort "complete replacement exceeded 50 ms" if replacement >= 50
end
