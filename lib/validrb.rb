# frozen_string_literal: true

require_relative "validrb/version"
require_relative "validrb/errors"
require_relative "validrb/result"
require_relative "validrb/constraints/base"
require_relative "validrb/constraints/min"
require_relative "validrb/constraints/max"
require_relative "validrb/constraints/length"
require_relative "validrb/constraints/format"
require_relative "validrb/constraints/enum"
require_relative "validrb/types/base"
require_relative "validrb/types/string"
require_relative "validrb/types/integer"
require_relative "validrb/types/float"
require_relative "validrb/types/boolean"
require_relative "validrb/types/array"
require_relative "validrb/types/object"
require_relative "validrb/types/date"
require_relative "validrb/types/datetime"
require_relative "validrb/types/time"
require_relative "validrb/types/decimal"
require_relative "validrb/field"
require_relative "validrb/schema"

module Validrb
  class << self
    # Main entry point for creating schemas
    # Options:
    #   strict: true - raise error on unknown keys
    #   passthrough: true - keep unknown keys in output
    def schema(**options, &block)
      Schema.new(**options, &block)
    end
  end
end
