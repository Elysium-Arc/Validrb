# frozen_string_literal: true

module Validrb
  module Constraints
    # Validates value is in an allowed list
    class Enum < Base
      attr_reader :allowed
      alias values allowed

      def initialize(allowed)
        @allowed = Array(allowed).freeze
        raise ArgumentError, "Enum requires at least one allowed value" if @allowed.empty?

        super()
      end

      def valid?(input)
        @allowed.include?(input)
      end

      def error_message(_input)
        formatted = @allowed.map(&:inspect).join(", ")
        "must be one of: #{formatted}"
      end

      def error_code
        :enum
      end
    end

    register(:enum, Enum)
  end
end
