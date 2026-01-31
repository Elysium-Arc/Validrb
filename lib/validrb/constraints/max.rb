# frozen_string_literal: true

module Validrb
  module Constraints
    # Validates maximum value (numbers) or maximum length (strings/arrays)
    class Max < Base
      attr_reader :value

      def initialize(value)
        @value = value
        super()
      end

      def valid?(input)
        comparable_value(input) <= @value
      end

      def error_message(input)
        if length_based?(input)
          "length must be at most #{@value} (got #{input.length})"
        else
          "must be at most #{@value}"
        end
      end

      def error_code
        :max
      end

      private

      def comparable_value(input)
        length_based?(input) ? input.length : input
      end

      def length_based?(input)
        input.respond_to?(:length) && !input.is_a?(Numeric)
      end
    end

    register(:max, Max)
  end
end
