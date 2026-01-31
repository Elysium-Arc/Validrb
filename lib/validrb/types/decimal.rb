# frozen_string_literal: true

require "bigdecimal"

module Validrb
  module Types
    # Decimal type using BigDecimal for precise monetary values
    class Decimal < Base
      def coerce(value)
        case value
        when ::BigDecimal
          return COERCION_FAILED unless value.finite?

          value
        when ::Integer
          BigDecimal(value)
        when ::Float
          return COERCION_FAILED unless value.finite?

          BigDecimal(value, ::Float::DIG)
        when ::String
          coerce_string(value)
        when ::Rational
          BigDecimal(value, ::Float::DIG)
        else
          COERCION_FAILED
        end
      end

      def valid?(value)
        value.is_a?(::BigDecimal) && value.finite?
      end

      def type_name
        "decimal"
      end

      private

      def coerce_string(value)
        stripped = value.strip
        return COERCION_FAILED if stripped.empty?

        # Validate format before conversion
        return COERCION_FAILED unless stripped.match?(/\A-?\d+(\.\d+)?\z/)

        result = BigDecimal(stripped)
        result.finite? ? result : COERCION_FAILED
      rescue ArgumentError
        COERCION_FAILED
      end
    end

    register(:decimal, Decimal)
    register(:bigdecimal, Decimal)
  end
end
