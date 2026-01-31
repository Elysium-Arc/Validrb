# frozen_string_literal: true

module Validrb
  module Types
    # Union type that accepts any of the specified types
    class Union < Base
      attr_reader :types

      def initialize(types:, **options)
        @types = resolve_types(types)
        super(**options)
      end

      def coerce(value)
        # Try each type in order, return first successful coercion
        @types.each do |type|
          result = type.coerce(value)
          return result unless result.equal?(COERCION_FAILED)
        end

        COERCION_FAILED
      end

      def valid?(value)
        @types.any? { |type| type.valid?(value) }
      end

      # Override call to try each type and return first success
      def call(value, path: [])
        errors = []

        @types.each do |type|
          coerced, type_errors = type.call(value, path: path)
          return [coerced, []] if type_errors.empty?

          errors.concat(type_errors)
        end

        # All types failed - return a union-specific error
        [nil, [Error.new(
          path: path,
          message: "must be one of: #{type_names.join(", ")}",
          code: :union_type_error
        )]]
      end

      def type_name
        "union<#{type_names.join(" | ")}>"
      end

      private

      def resolve_types(types)
        types.map do |type|
          case type
          when Symbol
            Types.build(type)
          when Types::Base
            type
          when Class
            type.new
          else
            raise ArgumentError, "Invalid type in union: #{type.inspect}"
          end
        end.freeze
      end

      def type_names
        @types.map(&:type_name)
      end
    end

    register(:union, Union)
  end
end
