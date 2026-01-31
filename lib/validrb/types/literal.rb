# frozen_string_literal: true

module Validrb
  module Types
    # Literal type for exact value matching
    # Accepts only specific values (like TypeScript literal types)
    class Literal < Base
      attr_reader :values

      def initialize(values:, **options)
        @values = Array(values).freeze
        super(**options)
      end

      def coerce(value)
        # No coercion for literals - must match exactly
        value
      end

      def valid?(value)
        @values.include?(value)
      end

      def type_name
        if @values.size == 1
          @values.first.inspect
        else
          @values.map(&:inspect).join(" | ")
        end
      end

      def coercion_error_message(value)
        "must be #{type_name}, got #{value.inspect}"
      end

      def validation_error_message(value)
        "must be #{type_name}, got #{value.inspect}"
      end
    end

    register(:literal, Literal)
  end
end
