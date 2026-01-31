# frozen_string_literal: true

module Validrb
  module Constraints
    # Validates exact length, range, or min/max length
    class Length < Base
      attr_reader :exact, :min, :max, :range

      def initialize(exact: nil, min: nil, max: nil, range: nil)
        @exact = exact
        @min = min
        @max = max
        @range = range
        validate_options!
        super()
      end

      def valid?(input)
        return false unless input.respond_to?(:length)

        len = input.length

        if @exact
          len == @exact
        elsif @range
          @range.include?(len)
        else
          (@min.nil? || len >= @min) && (@max.nil? || len <= @max)
        end
      end

      def error_message(input)
        len = input.respond_to?(:length) ? input.length : "N/A"

        if @exact
          "length must be exactly #{@exact} (got #{len})"
        elsif @range
          "length must be between #{@range.min} and #{@range.max} (got #{len})"
        elsif @min && @max
          "length must be between #{@min} and #{@max} (got #{len})"
        elsif @min
          "length must be at least #{@min} (got #{len})"
        else
          "length must be at most #{@max} (got #{len})"
        end
      end

      def error_code
        :length
      end

      def options
        {
          exact: @exact,
          min: @min,
          max: @max,
          range: @range
        }.compact
      end

      private

      def validate_options!
        return if @exact || @min || @max || @range

        raise ArgumentError, "Length constraint requires at least one of: exact, min, max, or range"
      end
    end

    register(:length, Length)
  end
end
