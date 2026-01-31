# frozen_string_literal: true

module Validrb
  # Schema class with DSL for defining fields
  class Schema
    attr_reader :fields

    def initialize(&block)
      @fields = {}
      @builder = Builder.new(self)
      @builder.instance_eval(&block) if block_given?
      @fields.freeze
      freeze
    end

    # Parse data and raise ValidationError on failure
    def parse(data, path_prefix: [])
      result = safe_parse(data, path_prefix: path_prefix)

      raise ValidationError, result.errors if result.failure?

      result.data
    end

    # Parse data and return Result (Success or Failure)
    def safe_parse(data, path_prefix: [])
      normalized = normalize_input(data)
      errors = []
      result_data = {}

      @fields.each do |name, field|
        value = fetch_value(normalized, name)
        coerced, field_errors = field.call(value, path: path_prefix)

        if field_errors.empty?
          # Only include in result if value is not nil or field has a value
          result_data[name] = coerced unless coerced.nil? && field.optional? && !field.has_default?
        else
          errors.concat(field_errors)
        end
      end

      if errors.empty?
        Success.new(result_data)
      else
        Failure.new(errors)
      end
    end

    # Add a field to the schema (used by Builder)
    def add_field(field)
      raise ArgumentError, "Field #{field.name} already defined" if @fields.key?(field.name)

      @fields[field.name] = field
    end

    private

    def normalize_input(data)
      return {} if data.nil?

      raise ArgumentError, "Expected Hash, got #{data.class}" unless data.is_a?(Hash)

      # Convert string keys to symbols
      data.transform_keys(&:to_sym)
    end

    def fetch_value(data, name)
      return data[name] if data.key?(name)

      # Also check string key
      string_key = name.to_s
      return data[string_key] if data.key?(string_key)

      Field::MISSING
    end

    # DSL Builder for defining fields
    class Builder
      def initialize(schema)
        @schema = schema
      end

      def field(name, type, **options)
        field = Field.new(name, type, **options)
        @schema.add_field(field)
      end

      # Shorthand for optional field
      def optional(name, type, **options)
        field(name, type, **options.merge(optional: true))
      end

      # Shorthand for required field (explicit)
      def required(name, type, **options)
        field(name, type, **options.merge(optional: false))
      end
    end
  end
end
