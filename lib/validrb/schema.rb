# frozen_string_literal: true

module Validrb
  # Schema class with DSL for defining fields
  class Schema
    attr_reader :fields, :validators, :options

    # Frozen empty collections for reuse
    EMPTY_ERRORS = [].freeze
    EMPTY_HASH = {}.freeze
    EMPTY_PATH = [].freeze

    # Options:
    #   strict: true - raise error on unknown keys
    #   strip: true - remove unknown keys (default behavior)
    #   passthrough: true - keep unknown keys in output
    def initialize(**options, &block)
      @fields = {}
      @validators = []
      @options = normalize_options(options)
      @builder = Builder.new(self)
      @builder.instance_eval(&block) if block_given?
      @fields.freeze
      @validators.freeze
      @has_validators = !@validators.empty?
      freeze
    end

    # Parse data and raise ValidationError on failure
    # @param data [Hash] The data to validate (can be passed as positional arg or kwargs)
    # @param path_prefix [Array] Path prefix for error messages
    # @param context [Context, Hash, nil] Optional validation context
    def parse(data = nil, path_prefix: [], context: nil, **data_kwargs)
      # Support both parse({ name: 'John' }) and parse(name: 'John')
      actual_data = data.nil? ? data_kwargs : data
      result = safe_parse(actual_data, path_prefix: path_prefix, context: context)

      raise ValidationError, result.errors if result.failure?

      result.data
    end

    # Parse data and return Result (Success or Failure)
    # @param data [Hash] The data to validate (can be passed as positional arg or kwargs)
    # @param path_prefix [Array] Path prefix for error messages
    # @param context [Context, Hash, nil] Optional validation context
    def safe_parse(data = nil, path_prefix: EMPTY_PATH, context: nil, **data_kwargs)
      # Support both safe_parse({ name: 'John' }) and safe_parse(name: 'John')
      actual_data = data.nil? ? data_kwargs : data
      normalized = normalize_input(actual_data)
      ctx = context ? normalize_context(context) : Context.empty
      errors = nil  # Lazy allocation
      result_data = {}

      # Check for unknown keys if strict mode
      if @options[:strict]
        normalized.each_key do |key|
          next if @fields.key?(key)

          errors ||= []
          errors << Error.new(path: path_prefix.empty? ? [key] : (path_prefix + [key]), message: "is not allowed", code: :unknown_key)
        end
      end

      # Validate each field
      @fields.each do |name, field|
        value = normalized.fetch(name, Field::MISSING)
        # Pass full data and context for conditional validation (when:/unless:)
        coerced, field_errors = field.call(value, path: path_prefix, data: normalized, context: ctx)

        if field_errors.empty?
          # Only include in result if value is not nil or field has a value
          # Also skip if field was conditionally skipped (conditional? && value is nil)
          should_include = !(coerced.nil? && field.optional? && !field.has_default?)
          should_include &&= !(coerced.nil? && field.conditional?)
          result_data[name] = coerced if should_include
        else
          errors ||= []
          errors.concat(field_errors)
        end
      end

      # Passthrough unknown keys
      if @options[:passthrough]
        normalized.each do |key, value|
          result_data[key] = value unless @fields.key?(key)
        end
      end

      # Run custom validators only if no field errors and has validators
      if errors.nil? && @has_validators
        validator_errors = run_validators(result_data, path_prefix, ctx)
        errors = validator_errors unless validator_errors.empty?
      end

      if errors
        Failure.new(errors)
      else
        Success.new(result_data)
      end
    end

    # Add a field to the schema (used by Builder)
    def add_field(field)
      raise ArgumentError, "Field #{field.name} already defined" if @fields.key?(field.name)

      @fields[field.name] = field
    end

    # Add a custom validator (used by Builder)
    def add_validator(validator)
      @validators << validator
    end

    # Schema composition methods

    # Create a new schema extending this one with additional fields
    def extend(**options, &block)
      parent_fields = @fields
      parent_validators = @validators
      parent_options = @options

      Schema.new(**parent_options.merge(options)) do
        # Copy parent fields
        parent_fields.each_value do |f|
          @schema.add_field(f)
        end
        # Copy parent validators
        parent_validators.each do |v|
          @schema.add_validator(v)
        end
        # Add new fields/validators from block
        instance_eval(&block) if block
      end
    end

    # Create a new schema with only specified fields
    def pick(*field_names, **options)
      field_names = field_names.map(&:to_sym)
      selected_fields = @fields.slice(*field_names)
      parent_options = @options

      Schema.new(**parent_options.merge(options)) do
        selected_fields.each_value do |f|
          @schema.add_field(f)
        end
      end
    end

    # Create a new schema without specified fields
    def omit(*field_names, **options)
      field_names = field_names.map(&:to_sym)
      remaining_fields = @fields.reject { |k, _| field_names.include?(k) }
      parent_options = @options

      Schema.new(**parent_options.merge(options)) do
        remaining_fields.each_value do |f|
          @schema.add_field(f)
        end
      end
    end

    # Merge another schema into this one (other schema's fields take precedence)
    def merge(other, **options)
      raise ArgumentError, "Expected Schema, got #{other.class}" unless other.is_a?(Schema)

      parent_fields = @fields
      parent_validators = @validators
      other_fields = other.fields
      other_validators = other.validators
      parent_options = @options

      Schema.new(**parent_options.merge(options)) do
        parent_fields.each_value do |f|
          @schema.add_field(f) unless other_fields.key?(f.name)
        end
        other_fields.each_value do |f|
          @schema.add_field(f)
        end
        parent_validators.each { |v| @schema.add_validator(v) }
        other_validators.each { |v| @schema.add_validator(v) }
      end
    end

    # Create a new schema with all fields optional
    def partial(**options)
      parent_fields = @fields
      parent_options = @options

      Schema.new(**parent_options.merge(options)) do
        parent_fields.each do |name, f|
          # Rebuild field as optional
          field = Field.new(
            name,
            f.type,
            optional: true,
            **f.options.reject { |k, _| k == :optional }
          )
          @schema.add_field(field)
        end
      end
    end

    private

    def normalize_options(options)
      {
        strict: options[:strict] || false,
        passthrough: options[:passthrough] || false
      }
    end

    def normalize_context(context)
      case context
      when Context
        context
      when Hash
        Context.new(**context)
      when nil
        Context.empty
      else
        raise ArgumentError, "Expected Context or Hash, got #{context.class}"
      end
    end

    def normalize_input(data)
      return EMPTY_HASH if data.nil?

      raise ArgumentError, "Expected Hash, got #{data.class}" unless data.is_a?(Hash)

      return data if data.empty?

      # Check if conversion is needed (any string keys?)
      needs_conversion = false
      data.each_key do |key|
        if key.is_a?(String)
          needs_conversion = true
          break
        end
      end

      needs_conversion ? data.transform_keys(&:to_sym) : data
    end

    def run_validators(data, path_prefix, context = nil)
      return EMPTY_ERRORS if @validators.empty?

      validator_ctx = ValidatorContext.new(data, path_prefix, context)

      @validators.each do |validator|
        if validator.arity <= 1
          validator_ctx.instance_exec(data, &validator)
        else
          validator_ctx.instance_exec(data, context, &validator)
        end
      end

      validator_ctx.errors
    end

    # Context object for custom validators
    class ValidatorContext
      attr_reader :errors, :context

      def initialize(data, path_prefix, context = nil)
        @data = data
        @path_prefix = path_prefix
        @context = context
        @errors = []
      end

      # Add an error for a specific field
      def error(field, message, code: :custom)
        path = @path_prefix + [field.to_sym]
        @errors << Error.new(path: path, message: message, code: code)
      end

      # Add a base-level error (not tied to a specific field)
      def base_error(message, code: :custom)
        @errors << Error.new(path: @path_prefix, message: message, code: code)
      end

      # Access field values
      def [](field)
        @data[field.to_sym]
      end
    end

    # DSL Builder for defining fields
    class Builder
      def initialize(schema)
        @schema = schema
      end

      # Define a field with optional inline schema block
      # @example Basic field
      #   field :name, :string
      # @example Object with inline schema
      #   field :address, :object do
      #     field :street, :string
      #     field :city, :string
      #   end
      # @example Array with inline item schema
      #   field :items, :array do
      #     field :product_id, :integer
      #     field :quantity, :integer
      #   end
      def field(name, type, **options, &block)
        if block_given?
          # Create inline nested schema from block
          inline_schema = Schema.new(&block)

          case type
          when :object, :hash
            options[:schema] = inline_schema
          when :array
            # For arrays, the block defines the item schema
            options[:of] = inline_schema
          end
        end

        field = Field.new(name, type, **options)
        @schema.add_field(field)
      end

      # Shorthand for optional field
      def optional(name, type, **options, &block)
        field(name, type, **options.merge(optional: true), &block)
      end

      # Shorthand for required field (explicit)
      def required(name, type, **options, &block)
        field(name, type, **options.merge(optional: false), &block)
      end

      # Add a custom validator block
      def validate(&block)
        @schema.add_validator(block)
      end
    end
  end
end
