# frozen_string_literal: true

module Validrb
  module Rails
    # Strong Parameters integration for Validrb schemas
    #
    # Automatically permits params based on schema field definitions,
    # eliminating the need for manual permit calls.
    #
    # @example In controller
    #   class UsersController < ApplicationController
    #     def create
    #       # Instead of: params.require(:user).permit(:name, :email, :age)
    #       # Just use:
    #       @user = User.create!(permitted_params(UserSchema, :user))
    #     end
    #   end
    #
    # @example With validation
    #   def create
    #     result = validated_params(UserSchema, :user)
    #     if result.success?
    #       @user = User.create!(result.data)
    #     else
    #       render json: { errors: result.errors }, status: :unprocessable_entity
    #     end
    #   end
    #
    # @example Bang version
    #   def create
    #     @user = User.create!(validated_params!(UserSchema, :user))
    #   end
    #
    module StrongParams
      extend ActiveSupport::Concern

      # Get permitted params based on schema without validation
      # @param schema [Validrb::Schema] The schema to derive permitted params from
      # @param key [Symbol, String, nil] Optional key to extract from params
      # @return [Hash] Permitted parameters
      def permitted_params(schema, key = nil)
        permit_list = build_permit_list(schema)

        if key
          params.require(key).permit(*permit_list).to_h.symbolize_keys
        else
          params.permit(*permit_list).to_h.symbolize_keys
        end
      end

      # Validate and return permitted params
      # @param schema [Validrb::Schema] The schema to validate against
      # @param key [Symbol, String, nil] Optional key to extract from params
      # @param context [Hash, Validrb::Context, nil] Optional validation context
      # @return [Validrb::Result] The validation result with permitted data
      def validated_params(schema, key = nil, context: nil)
        data = permitted_params(schema, key)
        ctx = build_context(context) if respond_to?(:build_context, true)
        schema.safe_parse(data, context: ctx)
      end

      # Validate and return permitted params, raising on failure
      # @param schema [Validrb::Schema] The schema to validate against
      # @param key [Symbol, String, nil] Optional key to extract from params
      # @param context [Hash, Validrb::Context, nil] Optional validation context
      # @return [Hash] The validated and coerced data
      # @raise [Controller::ValidationError] If validation fails
      def validated_params!(schema, key = nil, context: nil)
        result = validated_params(schema, key, context: context)
        raise Controller::ValidationError, result if result.failure?

        result.data
      end

      private

      # Build permit list from schema fields
      # Handles nested objects and arrays
      def build_permit_list(schema, prefix: nil)
        schema.fields.flat_map do |name, field|
          full_name = prefix ? :"#{prefix}.#{name}" : name
          field_permit_entry(name, field)
        end
      end

      def field_permit_entry(name, field)
        type = field.instance_variable_get(:@type)

        case type
        when Types::Object
          nested_schema = type.instance_variable_get(:@schema)
          if nested_schema
            # Nested object: { address: [:street, :city, :zip] }
            nested_permits = build_permit_list(nested_schema)
            { name => nested_permits }
          else
            name
          end
        when Types::Array
          item_type = type.instance_variable_get(:@item_type)
          if item_type.is_a?(Types::Object)
            nested_schema = item_type.instance_variable_get(:@schema)
            if nested_schema
              # Array of objects: { items: [:name, :quantity] }
              nested_permits = build_permit_list(nested_schema)
              { name => [nested_permits] }
            else
              { name => [] }
            end
          else
            # Array of primitives: tags: []
            { name => [] }
          end
        else
          # Simple field
          name
        end
      end
    end
  end
end
