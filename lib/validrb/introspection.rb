# frozen_string_literal: true

module Validrb
  # Schema introspection methods
  class Schema
    # Get field names
    def field_names
      @fields.keys
    end

    # Get a field by name
    def field(name)
      @fields[name.to_sym]
    end

    # Check if field exists
    def field?(name)
      @fields.key?(name.to_sym)
    end

    # Get required field names (excludes fields with defaults since they won't fail validation)
    def required_fields
      @fields.select { |_, f| f.required? && !f.conditional? && !f.has_default? }.keys
    end

    # Get optional field names
    def optional_fields
      @fields.select { |_, f| f.optional? }.keys
    end

    # Get conditional field names
    def conditional_fields
      @fields.select { |_, f| f.conditional? }.keys
    end

    # Get fields with defaults
    def fields_with_defaults
      @fields.select { |_, f| f.has_default? }.keys
    end

    # Get schema structure as a hash (for documentation/debugging)
    def to_schema_hash
      {
        fields: @fields.transform_values { |f| field_to_hash(f) },
        options: @options,
        validators_count: @validators.size
      }
    end

    # Generate JSON Schema (subset of JSON Schema Draft-07)
    def to_json_schema
      {
        "$schema" => "https://json-schema.org/draft-07/schema#",
        "type" => "object",
        "properties" => @fields.transform_values { |f| field_to_json_schema(f) }.transform_keys(&:to_s),
        "required" => required_fields.map(&:to_s),
        "additionalProperties" => @options[:passthrough] || !@options[:strict]
      }
    end

    private

    def field_to_hash(field)
      {
        type: field.type.type_name,
        optional: field.optional?,
        nullable: field.nullable?,
        has_default: field.has_default?,
        conditional: field.conditional?,
        constraints: field.constraints.map { |c| constraint_to_hash(c) }
      }
    end

    def constraint_to_hash(constraint)
      case constraint
      when Constraints::Min
        { type: :min, value: constraint.value }
      when Constraints::Max
        { type: :max, value: constraint.value }
      when Constraints::Length
        { type: :length, options: constraint.options }
      when Constraints::Format
        { type: :format, pattern: constraint.pattern.to_s }
      when Constraints::Enum
        { type: :enum, values: constraint.values }
      else
        { type: constraint.class.name }
      end
    end

    def field_to_json_schema(field)
      schema = {}

      # Map type to JSON Schema type
      type_mapping = type_to_json_schema(field.type)
      schema.merge!(type_mapping)

      # Handle nullable
      if field.nullable?
        if schema["type"].is_a?(::Array)
          schema["type"] << "null" unless schema["type"].include?("null")
        elsif schema["type"]
          schema["type"] = [schema["type"], "null"]
        end
      end

      # Handle default
      schema["default"] = field.default_value if field.has_default?

      # Handle constraints
      field.constraints.each do |constraint|
        case constraint
        when Constraints::Min
          if %w[integer number].include?(schema["type"]) || (schema["type"].is_a?(::Array) && (schema["type"] & %w[integer number]).any?)
            schema["minimum"] = constraint.value
          else
            schema["minLength"] = constraint.value
          end
        when Constraints::Max
          if %w[integer number].include?(schema["type"]) || (schema["type"].is_a?(::Array) && (schema["type"] & %w[integer number]).any?)
            schema["maximum"] = constraint.value
          else
            schema["maxLength"] = constraint.value
          end
        when Constraints::Length
          opts = constraint.options
          schema["minLength"] = opts[:min] if opts[:min]
          schema["maxLength"] = opts[:max] if opts[:max]
          if opts[:exact]
            schema["minLength"] = opts[:exact]
            schema["maxLength"] = opts[:exact]
          end
        when Constraints::Format
          # Only add pattern for regex formats
          schema["pattern"] = constraint.pattern.source if constraint.pattern.is_a?(Regexp)
        when Constraints::Enum
          schema["enum"] = constraint.values
        end
      end

      schema
    end

    def type_to_json_schema(type)
      case type
      when Types::String
        { "type" => "string" }
      when Types::Integer
        { "type" => "integer" }
      when Types::Float, Types::Decimal
        { "type" => "number" }
      when Types::Boolean
        { "type" => "boolean" }
      when Types::Array
        schema = { "type" => "array" }
        schema["items"] = type_to_json_schema(type.item_type) if type.respond_to?(:item_type) && type.item_type
        schema
      when Types::Object
        if type.respond_to?(:schema) && type.schema
          type.schema.to_json_schema.tap { |s| s.delete("$schema") }
        else
          { "type" => "object" }
        end
      when Types::Date, Types::DateTime, Types::Time
        { "type" => "string", "format" => "date-time" }
      when Types::Union
        { "oneOf" => type.types.map { |t| type_to_json_schema(t) } }
      when Types::Literal
        { "enum" => type.values }
      else
        { "type" => "string" }
      end
    end
  end

  # Field introspection
  class Field
    # Get constraint by type
    def constraint(type)
      @constraints.find { |c| c.is_a?(type) }
    end

    # Check if field has a specific constraint type
    def has_constraint?(type)
      @constraints.any? { |c| c.is_a?(type) }
    end

    # Get all constraint values as a hash
    def constraint_values
      @constraints.each_with_object({}) do |c, hash|
        case c
        when Constraints::Min
          hash[:min] = c.value
        when Constraints::Max
          hash[:max] = c.value
        when Constraints::Length
          hash[:length] = c.options
        when Constraints::Format
          hash[:format] = c.pattern
        when Constraints::Enum
          hash[:enum] = c.values
        end
      end
    end
  end
end
