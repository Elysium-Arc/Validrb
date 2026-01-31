# frozen_string_literal: true

module Validrb
  module Types
    # Integer type with coercion from String/Float
    class Integer < Base
      def coerce(value)
        case value
        when ::Integer
          value
        when ::Float
          # Only coerce whole numbers
          return COERCION_FAILED unless value.finite? && value == value.to_i

          value.to_i
        when ::String
          coerce_string(value)
        else
          COERCION_FAILED
        end
      end

      def valid?(value)
        value.is_a?(::Integer)
      end

      def type_name
        "integer"
      end

      private

      def coerce_string(value)
        stripped = value.strip
        return COERCION_FAILED if stripped.empty?

        # Try integer parse first
        if stripped.match?(/\A-?\d+\z/)
          return stripped.to_i
        end

        # Try float parse for strings like "42.0"
        if stripped.match?(/\A-?\d+\.0+\z/)
          return stripped.to_f.to_i
        end

        COERCION_FAILED
      end
    end

    register(:integer, Integer)
  end
end
