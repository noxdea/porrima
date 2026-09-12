# frozen_string_literal: true

module Porrima
  module_function

  def script(left, right)
    return right.map { |line| [:insert, line] } if left.empty?
    return left.map { |line| [:delete, line] } if right.empty?
    return left.map { |line| [:delete, line] } + right.map { |line| [:insert, line] } unless left.intersect?(right)
    x, y = bisect(left, right)
    if !x || (x.zero? && y.zero?) || (x == left.length && y == right.length)
      return left.map { |line| [:delete, line] } + right.map { |line| [:insert, line] }
    end
    [edits(left[0...x], right[0...y]), edits(left[x..], right[y..])].flatten.map { |edit| [edit.kind, edit.text] }
  end
  private_class_method :script

  def bisect(left, right)
    n, m = left.length, right.length
    limit = (n + m + 1) / 2
    forward = {1 => 0}
    reverse = {1 => 0}
    delta = n - m
    odd = delta.odd?
    (0..limit).each do |depth|
      (-depth..depth).step(2) do |k|
        x = k == -depth || (k != depth && forward.fetch(k - 1, -1) < forward.fetch(k + 1, -1)) ? forward.fetch(k + 1, 0) : forward.fetch(k - 1, 0) + 1
        y = x - k
        while x < n && y < m && x >= 0 && y >= 0 && left[x] == right[y]
          x += 1
          y += 1
        end
        forward[k] = x
        return [x, y] if odd && reverse.key?(delta - k) && x + reverse[delta - k] >= n
      end
      (-depth..depth).step(2) do |k|
        x = k == -depth || (k != depth && reverse.fetch(k - 1, -1) < reverse.fetch(k + 1, -1)) ? reverse.fetch(k + 1, 0) : reverse.fetch(k - 1, 0) + 1
        y = x - k
        while x < n && y < m && x >= 0 && y >= 0 && left[n - x - 1] == right[m - y - 1]
          x += 1
          y += 1
        end
        reverse[k] = x
        if !odd && forward.key?(delta - k) && forward[delta - k] + x >= n
          middle_x = forward[delta - k]
          return [middle_x, middle_x - (delta - k)]
        end
      end
    end
    nil
  end
  private_class_method :bisect
end
