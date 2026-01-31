# frozen_string_literal: true

module Validrb
  module Types
    # Array type with optional item type validation
    class Array < Base
      attr_reader :item_type

      def initialize(of: nil, **options)
        @item_type = of
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

        return [coerced, []] unless @item_type

        validate_items(coerced, path)
      end

      def type_name
        @item_type ? "array<#{item_type_name}>" : "array"
      end

      private

      def validate_items(array, path)
        type_instance = resolve_item_type
        result_array = []
        errors = []

        array.each_with_index do |item, index|
          item_path = path + [index]
          coerced_item, item_errors = type_instance.call(item, path: item_path)

          if item_errors.empty?
            result_array << coerced_item
          else
            errors.concat(item_errors)
          end
        end

        errors.empty? ? [result_array, []] : [nil, errors]
      end

      def resolve_item_type
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

      def item_type_name
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
