# frozen_string_literal: true

module Porrima
  class Budget
    attr_reader :max_bytes, :max_lines, :on_exceeded

    def initialize(max_bytes: nil, max_lines: nil, on_exceeded: :replace)
      raise ArgumentError, "max_bytes must be nonnegative" unless max_bytes.nil? || max_bytes.is_a?(Integer) && max_bytes >= 0
      raise ArgumentError, "max_lines must be nonnegative" unless max_lines.nil? || max_lines.is_a?(Integer) && max_lines >= 0
      raise ArgumentError, "on_exceeded must be :replace or :raise" unless %i[replace raise].include?(on_exceeded)
      @max_bytes, @max_lines, @on_exceeded = max_bytes, max_lines, on_exceeded
      freeze
    end

    def exceeded?(before, after)
      exceeded = max_lines && before.length + after.length > max_lines
      exceeded ||= max_bytes && before.sum(&:bytesize) + after.sum(&:bytesize) > max_bytes
      return false unless exceeded
      raise BudgetExceeded, "diff budget exceeded" if on_exceeded == :raise
      true
    end

    NONE = new
  end
end
