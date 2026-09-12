# frozen_string_literal: true

module Porrima
  class Error < StandardError; end
  class PatchError < Error; end
  class BudgetExceeded < Error; end
end
