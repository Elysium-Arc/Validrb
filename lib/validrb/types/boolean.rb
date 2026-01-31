# frozen_string_literal: true

module Validrb
  module Types
    # Boolean type with coercion from String/Integer
    class Boolean < Base
      TRUTHY_VALUES = [true, 1, "1", "true", "yes", "on", "t", "y"].freeze
      FALSY_VALUES = [false, 0, "0", "false", "no", "off", "f", "n"].freeze

      def coerce(value)
        return true if TRUTHY_VALUES.include?(normalize(value))
        return false if FALSY_VALUES.include?(normalize(value))

        COERCION_FAILED
      end

      def valid?(value)
        value.is_a?(TrueClass) || value.is_a?(FalseClass)
      end

      def type_name
        "boolean"
      end

      private

      def normalize(value)
        return value.downcase if value.is_a?(::String)

        value
      end
    end

    register(:boolean, Boolean)
    register(:bool, Boolean)
  end
end
