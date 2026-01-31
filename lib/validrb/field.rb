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

    attr_reader :name, :type, :constraints, :options, :refinements

    def initialize(name, type, **options)
      @name = name.to_sym
      @type = resolve_type(type, options)
      @constraints = build_constraints(options)
      @refinements = build_refinements(options)
      @options = extract_options(options)
      @transform = options[:transform]
      @preprocess = options[:preprocess]
      @message = options[:message]
      @coerce = options.fetch(:coerce, true)
      @when_condition = options[:when]
      @unless_condition = options[:unless]
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

    def conditional?
      !@when_condition.nil? || !@unless_condition.nil?
    end

    # Validate a value for this field
    # Returns [coerced_value, errors_array]
    # @param value - the value to validate
    # @param path - the path prefix for error messages
    # @param data - the full input data (for conditional validation)
    # @param context - optional validation context
    def call(value, path: [], data: nil, context: nil)
      field_path = path + [@name]

      # Check conditional validation (when:/unless:)
      if conditional? && !should_validate?(data, context)
        # Skip validation - treat as optional
        return [nil, []] if value.equal?(MISSING) || value.nil?

        # Still process the value if present (preprocess + transform)
        value = apply_preprocess(value, context) unless value.equal?(MISSING)
        return [apply_transform(value, context), []]
      end

      # Handle missing values
      if value.equal?(MISSING)
        return handle_missing_value(field_path, context)
      end

      # Apply preprocessing BEFORE type coercion
      value = apply_preprocess(value, context)

      # Handle nil values - nullable fields accept nil
      if value.nil?
        return [nil, []] if nullable?

        return handle_missing_value(field_path, context)
      end

      # Type coercion and validation
      coerced, type_errors = coerce_value(value, field_path)
      return [nil, apply_custom_message(type_errors)] unless type_errors.empty?

      # Constraint validation
      constraint_errors = validate_constraints(coerced, field_path)
      return [nil, apply_custom_message(constraint_errors)] unless constraint_errors.empty?

      # Refinement validation
      refinement_errors = validate_refinements(coerced, field_path, context)
      return [nil, apply_custom_message(refinement_errors)] unless refinement_errors.empty?

      # Apply transform if present
      coerced = apply_transform(coerced, context)

      [coerced, []]
    end

    private

    def resolve_type(type, options)
      # Handle literal types
      if options[:literal]
        return Types::Literal.new(values: options[:literal])
      end

      # Handle union types
      if options[:union]
        return Types::Union.new(types: options[:union])
      end

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
        of_option = options[:of]
        # If of: is a Schema, wrap it in an Object type
        if of_option.is_a?(Schema)
          { of: Types::Object.new(schema: of_option) }
        else
          { of: of_option }.compact
        end
      when :object, :hash
        { schema: options[:schema] }.compact
      when :discriminated_union
        {
          discriminator: options[:discriminator],
          mapping: options[:mapping]
        }.compact
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

    def build_refinements(options)
      refinements = []

      # Handle refine: option (single or array of procs/hashes)
      if options.key?(:refine)
        refine_opts = options[:refine]
        # Normalize to array - be careful with Hash (don't use Array())
        refine_opts = [refine_opts] unless refine_opts.is_a?(::Array)

        refine_opts.each do |refine_opt|
          case refine_opt
          when Proc
            refinements << { check: refine_opt, message: "failed refinement" }
          when Hash
            refinements << {
              check: refine_opt[:check] || refine_opt[:if],
              message: refine_opt[:message] || "failed refinement"
            }
          end
        end
      end

      refinements.freeze
    end

    def extract_options(options)
      {
        optional: options[:optional] || false,
        nullable: options[:nullable] || false,
        default: options[:default]
      }.tap { |h| h.delete(:default) unless options.key?(:default) }.freeze
    end

    def handle_missing_value(path, context = nil)
      # Apply default if present
      if has_default?
        value = default_value
        value = apply_preprocess(value, context) if @preprocess
        value = apply_transform(value, context) if @transform
        return [value, []]
      end

      # Optional fields can be missing
      if optional?
        return [nil, []]
      end

      # Required field is missing
      message = @message || I18n.t(:required)
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

    def validate_refinements(value, path, context = nil)
      errors = []
      @refinements.each do |refinement|
        check = refinement[:check]
        # Support context-aware refinements (2 or 3 args)
        result = if check.arity == 1
                   check.call(value)
                 elsif check.arity == 2
                   check.call(value, context)
                 else
                   check.call(value, context)
                 end

        unless result
          message = refinement[:message]
          message = message.call(value) if message.respond_to?(:call)
          errors << Error.new(path: path, message: message, code: :refinement)
        end
      end
      errors
    end

    def apply_custom_message(errors)
      return errors unless @message

      errors.map do |error|
        Error.new(path: error.path, message: @message, code: error.code)
      end
    end

    def apply_transform(value, context = nil)
      return value unless @transform

      # Support context-aware transforms
      if @transform.arity == 1
        @transform.call(value)
      else
        @transform.call(value, context)
      end
    end

    def apply_preprocess(value, context = nil)
      return value unless @preprocess

      # Support context-aware preprocessing
      if @preprocess.arity == 1
        @preprocess.call(value)
      else
        @preprocess.call(value, context)
      end
    end

    def coerce_value(value, path)
      if @coerce
        @type.call(value, path: path)
      else
        # No coercion - just validate the type
        if @type.valid?(value)
          [value, []]
        else
          [nil, [Error.new(path: path, message: @type.validation_error_message(value), code: :type_error)]]
        end
      end
    end

    def should_validate?(data, context = nil)
      return true if data.nil?

      # Check when: condition
      if @when_condition
        result = evaluate_condition(@when_condition, data, context)
        return false unless result
      end

      # Check unless: condition
      if @unless_condition
        result = evaluate_condition(@unless_condition, data, context)
        return false if result
      end

      true
    end

    def evaluate_condition(condition, data, context = nil)
      case condition
      when Proc
        # Support context-aware conditions
        if condition.arity == 1
          condition.call(data)
        else
          condition.call(data, context)
        end
      when Symbol
        # Symbol refers to a field value being truthy
        !!data[condition]
      else
        !!condition
      end
    end
  end
end
