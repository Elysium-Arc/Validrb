# frozen_string_literal: true

module Validrb
  module Constraints
    # Validates value matches a regex or named format
    class Format < Base
      NAMED_FORMATS = {
        email: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i,
        url: %r{\Ahttps?://[^\s/$.?#].[^\s]*\z}i,
        uuid: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
        phone: /\A\+?[\d\s\-().]{7,}\z/,
        alphanumeric: /\A[a-zA-Z0-9]+\z/,
        alpha: /\A[a-zA-Z]+\z/,
        numeric: /\A\d+\z/,
        hex: /\A[0-9a-fA-F]+\z/,
        slug: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
      }.freeze

      attr_reader :pattern, :format_name

      def initialize(pattern)
        @format_name = pattern.is_a?(Symbol) ? pattern : nil
        @pattern = resolve_pattern(pattern)
        super()
      end

      def valid?(input)
        return false unless input.is_a?(String)

        @pattern.match?(input)
      end

      def error_message(_input)
        if @format_name
          "must be a valid #{@format_name}"
        else
          "must match format #{@pattern.inspect}"
        end
      end

      def error_code
        :format
      end

      private

      def resolve_pattern(pattern)
        case pattern
        when Regexp
          pattern
        when Symbol
          NAMED_FORMATS.fetch(pattern) do
            raise ArgumentError, "Unknown format: #{pattern}. Available: #{NAMED_FORMATS.keys.join(", ")}"
          end
        else
          raise ArgumentError, "Format must be a Regexp or Symbol, got #{pattern.class}"
        end
      end
    end

    register(:format, Format)
  end
end
