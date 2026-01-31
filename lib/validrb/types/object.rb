# frozen_string_literal: true

module Validrb
  module Types
    # Object type for nested schema validation
    class Object < Base
      attr_reader :schema

      def initialize(schema: nil, **options)
        @schema = schema
        super(**options)
      end

      def coerce(value)
        return COERCION_FAILED unless value.is_a?(Hash)

        value
      end

      def valid?(value)
        value.is_a?(Hash)
      end

      # Override call to delegate to nested schema
      def call(value, path: EMPTY_PATH)
        coerced = coerce(value)

        if coerced.equal?(COERCION_FAILED)
          return [nil, [Error.new(path: path, message: coercion_error_message(value), code: :type_error)]]
        end

        return [coerced, EMPTY_ERRORS] unless @schema

        # Delegate to nested schema with path prefix
        result = @schema.safe_parse(coerced, path_prefix: path)

        if result.success?
          [result.data, EMPTY_ERRORS]
        else
          [nil, result.errors.to_a]
        end
      end

      def type_name
        "object"
      end
    end

    register(:object, Object)
    register(:hash, Object)
  end
end
