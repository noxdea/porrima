# frozen_string_literal: true

require "fileutils"
require "porrima"
require_relative "png_helper"

before = "alpha\nbeta\ngamma\ndelta\n"
after = "alpha\nbeta changed\ngamma\nepsilon\n"
edits = Porrima.diff(before, after).edits
width = 1_000
height = 520
rgba = [24, 29, 38, 255] * width * height
rect = lambda do |x, y, w, h, color|
  h.times { |row| w.times { |column| rgba[((y + row) * width + x + column) * 4, 4] = color } }
end
edits.each_with_index do |edit, row|
  y = 32 + row * 72
  color = {equal: [76, 92, 110, 255], delete: [248, 113, 113, 255], insert: [82, 220, 151, 255]}.fetch(edit.kind)
  rect.call(42, y, 420, 42, color)
  rect.call(538, y, 420, 42, color)
  rect.call(42, y + 48, 916, 2, [55, 65, 78, 255])
end
FileUtils.mkdir_p("docs/media")
DemoPNG.write("docs/media/screenshot.png", width, height, rgba.pack("C*"))
