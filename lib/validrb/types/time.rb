# frozen_string_literal: true

require "time"

module Validrb
  module Types
    # Time type with coercion from String (ISO8601) and Date/DateTime
    class Time < Base
      def coerce(value)
        case value
        when ::Time
          value
        when ::DateTime
          value.to_time
        when ::Date
          value.to_time
        when ::String
          coerce_string(value)
        when ::Integer
          # Unix timestamp
          ::Time.at(value)
        when ::Float
          # Unix timestamp with fractional seconds
          ::Time.at(value)
        else
          COERCION_FAILED
        end
      end

      def valid?(value)
        value.is_a?(::Time)
      end

      def type_name
        "time"
      end

      private

      def coerce_string(value)
        stripped = value.strip
        return COERCION_FAILED if stripped.empty?

        # Try ISO8601 first
        begin
          return ::Time.iso8601(stripped)
        rescue ArgumentError
          # Continue
        end

        # Try RFC2822
        begin
          return ::Time.rfc2822(stripped)
        rescue ArgumentError
          # Continue
        end

        # Try Ruby's flexible parsing
        begin
          return ::Time.parse(stripped)
        rescue ArgumentError
          COERCION_FAILED
        end
      end
    end

    register(:time, Time)
  end
end
