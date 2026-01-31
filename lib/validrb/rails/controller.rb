# frozen_string_literal: true

module Validrb
  module Rails
    # Controller helpers for validating params with Validrb schemas
    #
    # @example Include in ApplicationController
    #   class ApplicationController < ActionController::Base
    #     include Validrb::Rails::Controller
    #   end
    #
    # @example Validate params
    #   class UsersController < ApplicationController
    #     UserSchema = Validrb.schema do
    #       field :name, :string, min: 2
    #       field :email, :string, format: :email
    #     end
    #
    #     def create
    #       result = validate_params(UserSchema, :user)
    #       if result.success?
    #         @user = User.create!(result.data)
    #         redirect_to @user
    #       else
    #         @errors = result.errors
    #         render :new, status: :unprocessable_entity
    #       end
    #     end
    #   end
    #
    # @example With validate_params!
    #   def create
    #     data = validate_params!(UserSchema, :user)  # Raises on failure
    #     @user = User.create!(data)
    #   end
    #
    module Controller
      extend ActiveSupport::Concern

      class ValidationError < StandardError
        attr_reader :errors, :result

        def initialize(result)
          @result = result
          @errors = result.errors
          super("Validation failed: #{errors.map(&:message).join(', ')}")
        end
      end

      # Validate params against a schema
      # @param schema [Validrb::Schema] The schema to validate against
      # @param key [Symbol, String, nil] Optional key to extract from params
      # @param context [Hash, Validrb::Context, nil] Optional validation context
      # @return [Validrb::Result] The validation result
      def validate_params(schema, key = nil, context: nil)
        data = extract_params(key)
        schema.safe_parse(data, context: build_context(context))
      end

      # Validate params and raise on failure
      # @param schema [Validrb::Schema] The schema to validate against
      # @param key [Symbol, String, nil] Optional key to extract from params
      # @param context [Hash, Validrb::Context, nil] Optional validation context
      # @return [Hash] The validated data
      # @raise [ValidationError] If validation fails
      def validate_params!(schema, key = nil, context: nil)
        result = validate_params(schema, key, context: context)
        raise ValidationError, result if result.failure?

        result.data
      end

      # Build a form object from params
      # @param form_class [Class] The FormObject subclass
      # @param key [Symbol, String, nil] Optional key to extract from params
      # @return [FormObject] The form object instance
      def build_form(form_class, key = nil)
        data = extract_params(key)
        form_class.new(data)
      end

      private

      def extract_params(key)
        if key
          # Try both symbol and string keys
          data = params[key] || params[key.to_s]
        else
          data = params
        end

        # Handle ActionController::Parameters if available
        if defined?(ActionController::Parameters) && data.is_a?(ActionController::Parameters)
          data.to_unsafe_h.transform_keys(&:to_sym)
        elsif data.is_a?(Hash)
          data.transform_keys(&:to_sym)
        else
          {}
        end
      end

      def build_context(context)
        base_context = {
          current_user: (current_user if respond_to?(:current_user, true)),
          request: request,
          params: params
        }.compact

        case context
        when Hash
          Validrb.context(**base_context.merge(context))
        when Validrb::Context
          context
        else
          Validrb.context(**base_context)
        end
      end
    end
  end
end
