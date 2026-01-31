# frozen_string_literal: true

module Validrb
  # Represents a field definition with type, constraints, and options
  class Field
    # Sentinel for missing values (distinguishes from nil)
    MISSING = Object.new.tap do |obj|
      def obj.inspect
        "MISSING"
      end

      def obj.to_s
        "MISSING"
      end
    end.freeze

    attr_reader :name, :type, :constraints, :options

    def initialize(name, type, **options)
      @name = name.to_sym
      @type = resolve_type(type, options)
      @constraints = build_constraints(options)
      @options = extract_options(options)
      @transform = options[:transform]
      @message = options[:message]
      freeze
    end

    def optional?
      @options[:optional] == true
    end

    def required?
      !optional?
    end

    def nullable?
      @options[:nullable] == true
    end

    def has_default?
      @options.key?(:default)
    end

    def default_value
      value = @options[:default]
      value.respond_to?(:call) ? value.call : value
    end

    # Validate a value for this field
    # Returns [coerced_value, errors_array]
    def call(value, path: [])
      field_path = path + [@name]

      # Handle missing values
      if value.equal?(MISSING)
        return handle_missing_value(field_path)
      end

      # Handle nil values - nullable fields accept nil
      if value.nil?
        return [nil, []] if nullable?

        return handle_missing_value(field_path)
      end

      # Type coercion and validation
      coerced, type_errors = @type.call(value, path: field_path)
      return [nil, apply_custom_message(type_errors)] unless type_errors.empty?

      # Constraint validation
      constraint_errors = validate_constraints(coerced, field_path)
      return [nil, apply_custom_message(constraint_errors)] unless constraint_errors.empty?

      # Apply transform if present
      coerced = apply_transform(coerced)

      [coerced, []]
    end

    private

    def resolve_type(type, options)
      case type
      when Symbol
        type_options = extract_type_options(type, options)
        Types.build(type, **type_options)
      when Types::Base
        type
      when Class
        type.new
      else
        raise ArgumentError, "Invalid type: #{type.inspect}"
      end
    end

    def extract_type_options(type, options)
      case type
      when :array
        { of: options[:of] }.compact
      when :object, :hash
        { schema: options[:schema] }.compact
      else
        {}
      end
    end

    def build_constraints(options)
      constraints = []

      # Min constraint
      constraints << Constraints::Min.new(options[:min]) if options.key?(:min)

      # Max constraint
      constraints << Constraints::Max.new(options[:max]) if options.key?(:max)

      # Length constraint
      if options.key?(:length)
        length_opts = options[:length]
        case length_opts
        when Integer
          constraints << Constraints::Length.new(exact: length_opts)
        when Range
          constraints << Constraints::Length.new(range: length_opts)
        when Hash
          constraints << Constraints::Length.new(**length_opts)
        end
      end

      # Format constraint
      constraints << Constraints::Format.new(options[:format]) if options.key?(:format)

      # Enum constraint
      constraints << Constraints::Enum.new(options[:enum]) if options.key?(:enum)

      constraints.freeze
    end

    def extract_options(options)
      {
        optional: options[:optional] || false,
        nullable: options[:nullable] || false,
        default: options[:default]
      }.tap { |h| h.delete(:default) unless options.key?(:default) }.freeze
    end

    def handle_missing_value(path)
      # Apply default if present
      if has_default?
        value = default_value
        value = apply_transform(value) if @transform
        return [value, []]
      end

      # Optional fields can be missing
      if optional?
        return [nil, []]
      end

      # Required field is missing
      message = @message || "is required"
      error = Error.new(path: path, message: message, code: :required)
      [nil, [error]]
    end

    def validate_constraints(value, path)
      errors = []
      @constraints.each do |constraint|
        constraint_errors = constraint.call(value, path: path)
        errors.concat(constraint_errors)
      end
      errors
    end

    def apply_custom_message(errors)
      return errors unless @message

      errors.map do |error|
        Error.new(path: error.path, message: @message, code: error.code)
      end
    end

    def apply_transform(value)
      return value unless @transform

      @transform.call(value)
    end
  end
end
