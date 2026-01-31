# frozen_string_literal: true

module Validrb
  module Types
    # Discriminated union type - selects schema based on discriminator field
    # More efficient than regular unions for object types
    class DiscriminatedUnion < Base
      attr_reader :discriminator, :mapping

      # @param discriminator [Symbol] The field to use as discriminator
      # @param mapping [Hash<value, Schema>] Maps discriminator values to schemas
      def initialize(discriminator:, mapping:, **options)
        @discriminator = discriminator.to_sym
        @mapping = mapping.transform_keys { |k| k.is_a?(Symbol) ? k.to_s : k }.freeze
        super(**options)
      end

      def call(value, path: [])
        unless value.is_a?(Hash)
          return [nil, [Error.new(path: path, message: "must be an object", code: :type_error)]]
        end

        # Normalize input
        normalized = value.transform_keys { |k| k.is_a?(Symbol) ? k.to_s : k }
        disc_value = normalized[@discriminator.to_s]

        if disc_value.nil?
          return [nil, [Error.new(
            path: path + [@discriminator],
            message: "discriminator field is required",
            code: :discriminator_missing
          )]]
        end

        # Convert symbol to string for lookup
        lookup_value = disc_value.is_a?(Symbol) ? disc_value.to_s : disc_value
        schema = @mapping[lookup_value]

        if schema.nil?
          valid_values = @mapping.keys.map(&:inspect).join(", ")
          return [nil, [Error.new(
            path: path + [@discriminator],
            message: "must be one of: #{valid_values}",
            code: :invalid_discriminator
          )]]
        end

        # Validate with the selected schema
        result = schema.safe_parse(value, path_prefix: path)

        if result.success?
          [result.data, []]
        else
          [nil, result.errors.to_a]
        end
      end

      def coerce(value)
        value
      end

      def valid?(value)
        value.is_a?(Hash)
      end

      def type_name
        values = @mapping.keys.map(&:inspect).join(" | ")
        "discriminated_union<#{@discriminator}: #{values}>"
      end
    end

    register(:discriminated_union, DiscriminatedUnion)
  end
end
