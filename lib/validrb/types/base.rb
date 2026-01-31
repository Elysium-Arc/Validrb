# frozen_string_literal: true

module Validrb
  module Types
    # Sentinel object for failed coercion (distinguishes from nil)
    COERCION_FAILED = Object.new.tap do |obj|
      def obj.inspect
        "COERCION_FAILED"
      end

      def obj.to_s
        "COERCION_FAILED"
      end
    end.freeze

    # Frozen empty collections for reuse (reduces allocations)
    EMPTY_ERRORS = [].freeze
    EMPTY_PATH = [].freeze

    # Registry for types
    @registry = {}

    class << self
      attr_reader :registry

      def register(name, klass)
        @registry[name.to_sym] = klass
      end

      def lookup(name)
        @registry[name.to_sym]
      end

      def build(name, **options)
        klass = lookup(name)
        raise ArgumentError, "Unknown type: #{name}" unless klass

        klass.new(**options)
      end
    end

    # Base class for all types
    class Base
      attr_reader :options

      def initialize(**options)
        @options = options.freeze
        freeze
      end

      # Main entry point: coerce and validate a value
      # Returns [coerced_value, errors_array]
      def call(value, path: EMPTY_PATH)
        coerced = coerce(value)

        if coerced.equal?(COERCION_FAILED)
          return [nil, [Error.new(path: path, message: coercion_error_message(value), code: :type_error)]]
        end

        unless valid?(coerced)
          return [nil, [Error.new(path: path, message: validation_error_message(coerced), code: :type_error)]]
        end

        [coerced, EMPTY_ERRORS]
      end

      # Override in subclasses: attempt to coerce value to target type
      # Return COERCION_FAILED if coercion is not possible
      def coerce(value)
        value
      end

      # Override in subclasses: validate that value is correct type
      def valid?(_value)
        true
      end

      # Override in subclasses: type name for error messages
      def type_name
        self.class.name.split("::").last.downcase
      end

      # Override in subclasses: error message for failed coercion
      def coercion_error_message(value)
        "cannot coerce #{value.class} to #{type_name}"
      end

      # Override in subclasses: error message for failed validation
      def validation_error_message(_value)
        "must be a #{type_name}"
      end
    end
  end
end
