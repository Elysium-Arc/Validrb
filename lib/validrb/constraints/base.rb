# frozen_string_literal: true

module Validrb
  module Constraints
    # Frozen empty array for reuse
    EMPTY_ERRORS = [].freeze

    # Registry for constraint types
    @registry = {}

    class << self
      attr_reader :registry

      def register(name, klass)
        @registry[name.to_sym] = klass
      end

      def lookup(name)
        @registry[name.to_sym]
      end

      def build(name, *args, **kwargs)
        klass = lookup(name)
        raise ArgumentError, "Unknown constraint: #{name}" unless klass

        klass.new(*args, **kwargs)
      end
    end

    # Base class for all constraints
    class Base
      attr_reader :options

      def initialize(**options)
        @options = options.freeze
        freeze
      end

      # Validate a value and return an array of Error objects (empty if valid)
      def call(value, path: [])
        return EMPTY_ERRORS if valid?(value)

        [Error.new(path: path, message: error_message(value), code: error_code)]
      end

      # Override in subclasses to implement validation logic
      def valid?(_value)
        raise NotImplementedError, "#{self.class}#valid? must be implemented"
      end

      # Override in subclasses to provide error message
      def error_message(_value)
        raise NotImplementedError, "#{self.class}#error_message must be implemented"
      end

      # Override in subclasses to provide error code
      def error_code
        :constraint_error
      end
    end
  end
end
