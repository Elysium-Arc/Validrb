# frozen_string_literal: true

module Validrb
  module Types
    # String type with coercion from Symbol/Numeric
    class String < Base
      def coerce(value)
        case value
        when ::String
          value
        when Symbol, Numeric
          value.to_s
        else
          COERCION_FAILED
        end
      end

      def valid?(value)
        value.is_a?(::String)
      end

      def type_name
        "string"
      end
    end

    register(:string, String)
  end
end
