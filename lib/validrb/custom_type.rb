# frozen_string_literal: true

module Validrb
  # DSL for defining custom types easily
  # Example:
  #   Validrb.define_type(:email) do
  #     coerce { |v| v.to_s.strip.downcase }
  #     validate { |v| v.match?(/\A[^@\s]+@[^@\s]+\z/) }
  #     error_message { |v| "must be a valid email address" }
  #   end
  module CustomType
    class Builder
      def initialize
        @coercer = nil
        @validator = nil
        @error_message_proc = nil
        @type_name = nil
      end

      # Define coercion logic
      def coerce(&block)
        @coercer = block
      end

      # Define validation logic
      def validate(&block)
        @validator = block
      end

      # Define custom error message
      def error_message(&block)
        @error_message_proc = block
      end

      # Set the type name for error messages
      def name(type_name)
        @type_name = type_name
      end

      def build(type_sym)
        coercer = @coercer
        validator = @validator
        error_proc = @error_message_proc
        type_name_val = @type_name || type_sym.to_s

        Class.new(Types::Base) do
          define_method(:coerce) do |value|
            return value unless coercer

            begin
              coercer.call(value)
            rescue StandardError
              Types::COERCION_FAILED
            end
          end

          define_method(:valid?) do |value|
            return true unless validator

            validator.call(value)
          end

          define_method(:type_name) do
            type_name_val
          end

          if error_proc
            define_method(:validation_error_message) do |value|
              error_proc.call(value)
            end

            define_method(:coercion_error_message) do |value|
              error_proc.call(value)
            end
          end
        end
      end
    end

    def self.define(type_sym, &block)
      builder = Builder.new
      builder.instance_eval(&block)
      klass = builder.build(type_sym)
      Types.register(type_sym, klass)
      klass
    end
  end

  class << self
    # Public API for defining custom types
    def define_type(type_sym, &block)
      CustomType.define(type_sym, &block)
    end
  end
end
