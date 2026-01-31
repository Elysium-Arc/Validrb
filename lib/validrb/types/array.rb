# frozen_string_literal: true

module Validrb
  module Types
    # Array type with optional item type validation
    class Array < Base
      attr_reader :item_type

      # Frozen empty array for reuse
      EMPTY_ARRAY = [].freeze
      EMPTY_ERRORS = [].freeze

      def initialize(of: nil, **options)
        @item_type = of
        # Cache resolved item type at initialization (before freeze)
        @resolved_item_type = resolve_item_type_once if @item_type
        @item_type_name = compute_item_type_name if @item_type
        super(**options)
      end

      def coerce(value)
        return COERCION_FAILED unless value.is_a?(::Array)

        value
      end

      def valid?(value)
        value.is_a?(::Array)
      end

      # Override call to handle item validation
      def call(value, path: [])
        coerced = coerce(value)

        if coerced.equal?(COERCION_FAILED)
          return [nil, [Error.new(path: path, message: coercion_error_message(value), code: :type_error)]]
        end

        return [coerced, EMPTY_ERRORS] unless @item_type

        validate_items(coerced, path)
      end

      def type_name
        @item_type ? "array<#{@item_type_name}>" : "array"
      end

      private

      def validate_items(array, path)
        # Fast path for empty arrays
        return [EMPTY_ARRAY, EMPTY_ERRORS] if array.empty?

        type_instance = @resolved_item_type
        size = array.size
        result_array = ::Array.new(size)
        errors = nil

        # Optimize: pre-build path once and reuse for simple types
        # For nested schemas, we still need to build per-item paths
        if type_instance.is_a?(Types::Object) && type_instance.schema
          # Nested schema - needs full path for each item
          array.each_with_index do |item, index|
            coerced_item, item_errors = type_instance.call(item, path: path + [index])

            if item_errors.empty?
              result_array[index] = coerced_item
            else
              errors ||= []
              errors.concat(item_errors)
            end
          end
        else
          # Simple type - can build path lazily only on error
          array.each_with_index do |item, index|
            coerced_item, item_errors = type_instance.call(item, path: EMPTY_PATH)

            if item_errors.empty?
              result_array[index] = coerced_item
            else
              errors ||= []
              # Rebuild errors with correct path
              item_errors.each do |err|
                errors << Error.new(
                  path: path + [index] + err.path,
                  message: err.message,
                  code: err.code
                )
              end
            end
          end
        end

        errors ? [nil, errors] : [result_array, EMPTY_ERRORS]
      end

      def resolve_item_type_once
        case @item_type
        when Symbol
          Types.build(@item_type)
        when Types::Base
          @item_type
        when Class
          @item_type.new
        when ::Validrb::Schema
          # Schema instance - wrap in Object type
          Types::Object.new(schema: @item_type)
        else
          raise ArgumentError, "Invalid item type: #{@item_type.inspect}"
        end
      end

      def compute_item_type_name
        case @item_type
        when Symbol
          @item_type.to_s
        when Types::Base
          @item_type.type_name
        when Class
          @item_type.name.split("::").last.downcase
        when ::Validrb::Schema
          "object"
        else
          "unknown"
        end
      end
    end

    register(:array, Array)
  end
end
