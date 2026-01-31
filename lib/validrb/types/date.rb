# frozen_string_literal: true

require "date"

module Validrb
  module Types
    # Date type with coercion from String (ISO8601) and Time/DateTime
    class Date < Base
      # Common date formats to try (ISO8601-like formats only to avoid ambiguity)
      DATE_FORMATS = [
        "%Y-%m-%d",      # 2024-01-15 (ISO8601)
        "%Y/%m/%d"       # 2024/01/15
      ].freeze

      def coerce(value)
        case value
        when ::DateTime
          # DateTime is a subclass of Date, so check it first
          ::Date.new(value.year, value.month, value.day)
        when ::Date
          value
        when ::Time
          value.to_date
        when ::String
          coerce_string(value)
        when ::Integer
          # Unix timestamp
          ::Time.at(value).to_date
        else
          COERCION_FAILED
        end
      end

      def valid?(value)
        value.is_a?(::Date) && !value.is_a?(::DateTime)
      end

      def type_name
        "date"
      end

      private

      def coerce_string(value)
        stripped = value.strip
        return COERCION_FAILED if stripped.empty?

        # Try ISO8601 first (most common)
        begin
          return ::Date.iso8601(stripped)
        rescue ArgumentError
          # Continue to other formats
        end

        # Try other common formats
        DATE_FORMATS.each do |format|
          begin
            return ::Date.strptime(stripped, format)
          rescue ArgumentError
            next
          end
        end

        COERCION_FAILED
      end
    end

    register(:date, Date)
  end
end
