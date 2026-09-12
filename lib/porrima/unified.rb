# frozen_string_literal: true

module Porrima
  def unified(before, after, old_name: "a/file", new_name: "b/file", context: 3, budget: nil)
    output = +"--- #{old_name}\n+++ #{new_name}\n"
    hunks(before, after, context: context, budget: budget).each do |hunk|
      output << "@@ -#{hunk.old_start},#{hunk.old_count} +#{hunk.new_start},#{hunk.new_count} @@\n"
      hunk.edits.each do |edit|
        output << {equal: " ", delete: "-", insert: "+"}.fetch(edit.kind) << edit.text
        output << "\n\\ No newline at end of file\n" unless edit.text.end_with?("\n")
      end
    end
    output
  end
  module_function :unified
end
