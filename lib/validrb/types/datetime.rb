# frozen_string_literal: true

require "date"
require "time"

module Validrb
  module Types
    # DateTime type with coercion from String (ISO8601) and Time/Date
    class DateTime < Base
      def coerce(value)
        case value
        when ::DateTime
          value
        when ::Time
          value.to_datetime
        when ::Date
          value.to_datetime
        when ::String
          coerce_string(value)
        when ::Integer
          # Unix timestamp
          ::Time.at(value).to_datetime
        when ::Float
          # Unix timestamp with fractional seconds
          ::Time.at(value).to_datetime
        else
          COERCION_FAILED
        end
      end

      def valid?(value)
        value.is_a?(::DateTime)
      end

      def type_name
        "datetime"
      end

      private

      def coerce_string(value)
        stripped = value.strip
        return COERCION_FAILED if stripped.empty?

        # Try ISO8601 first
        begin
          return ::DateTime.iso8601(stripped)
        rescue ArgumentError
          # Continue
        end

        # Try RFC2822 (email date format)
        begin
          return ::DateTime.rfc2822(stripped)
        rescue ArgumentError
          # Continue
        end

        # Try Ruby's flexible parsing
        begin
          return ::DateTime.parse(stripped)
        rescue ArgumentError
          COERCION_FAILED
        end
      end
    end

    register(:datetime, DateTime)
    register(:date_time, DateTime)
  end
end
