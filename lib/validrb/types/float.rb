# frozen_string_literal: true

module Validrb
  module Types
    # Float type with coercion from String/Integer
    class Float < Base
      def coerce(value)
        case value
        when ::Float
          return COERCION_FAILED unless value.finite?

          value
        when ::Integer
          value.to_f
        when ::String
          coerce_string(value)
        else
          COERCION_FAILED
        end
      end

      def valid?(value)
        value.is_a?(::Float) && value.finite?
      end

      def type_name
        "float"
      end

      private

      def coerce_string(value)
        stripped = value.strip
        return COERCION_FAILED if stripped.empty?

        # Match integer or float format
        return COERCION_FAILED unless stripped.match?(/\A-?\d+(\.\d+)?\z/)

        result = stripped.to_f
        result.finite? ? result : COERCION_FAILED
      end
    end

    register(:float, Float)
  end
end
