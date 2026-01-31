# frozen_string_literal: true

module Validrb
  module Rails
    # ActiveRecord model integration for Validrb schemas
    #
    # @example Basic usage
    #   class User < ApplicationRecord
    #     include Validrb::Rails::Model
    #
    #     validates_with_schema do
    #       field :name, :string, min: 2, max: 100
    #       field :email, :string, format: :email
    #       field :age, :integer, min: 0, optional: true
    #     end
    #   end
    #
    # @example With existing schema
    #   class User < ApplicationRecord
    #     include Validrb::Rails::Model
    #
    #     validates_with_schema UserSchema
    #   end
    #
    # @example With context
    #   class User < ApplicationRecord
    #     include Validrb::Rails::Model
    #
    #     validates_with_schema UserSchema, context: ->(record) {
    #       { is_admin: record.admin?, current_record: record }
    #     }
    #   end
    #
    module Model
      extend ActiveSupport::Concern

      class_methods do
        # Define schema validation for this model
        # @param schema [Validrb::Schema, nil] An existing schema (optional)
        # @param only [Array<Symbol>] Only validate these attributes
        # @param except [Array<Symbol>] Don't validate these attributes
        # @param on [Symbol, Array<Symbol>] Validation context (:create, :update)
        # @param context [Proc, Hash] Validation context builder
        # @yield Block defining the schema (if no schema given)
        def validates_with_schema(schema = nil, only: nil, except: nil, on: nil, context: nil, &block)
          if block_given?
            schema = Validrb.schema(&block)
          end

          raise ArgumentError, "Schema required (pass a schema or provide a block)" unless schema

          # Store schema configuration
          @validrb_schema_config = {
            schema: schema,
            only: only,
            except: except,
            on: on,
            context: context
          }

          # Add the validator
          if on
            validate :validate_with_validrb_schema, on: on
          else
            validate :validate_with_validrb_schema
          end
        end

        # Get the configured schema
        def validrb_schema
          @validrb_schema_config&.dig(:schema)
        end

        # Get the schema configuration
        def validrb_schema_config
          @validrb_schema_config
        end
      end

      # Validate the model using the Validrb schema
      def validate_with_validrb_schema
        config = self.class.validrb_schema_config
        return unless config

        schema = config[:schema]
        return unless schema

        # Apply :only/:except to schema
        schema = build_filtered_schema(schema, config)

        # Build attributes hash (filtered to match schema)
        attrs = validrb_attributes(config)

        # Build context
        ctx = build_validrb_context(config[:context])

        # Run validation
        result = schema.safe_parse(attrs, context: ctx)

        # Add errors if validation failed
        if result.failure?
          ErrorConverter.add_to_active_model(result.errors, errors)
        end
      end

      # Validate with a specific schema (ad-hoc validation)
      # @param schema [Validrb::Schema] The schema to validate against
      # @param attributes [Hash, nil] Attributes to validate (defaults to model attributes)
      # @param context [Hash, nil] Validation context
      # @return [Boolean] Whether validation passed
      def valid_for_schema?(schema, attributes: nil, context: nil)
        attrs = attributes || self.attributes.symbolize_keys
        ctx = context ? Validrb.context(**context) : nil

        result = schema.safe_parse(attrs, context: ctx)

        if result.failure?
          ErrorConverter.add_to_active_model(result.errors, errors)
          false
        else
          true
        end
      end

      private

      def validrb_attributes(config)
        attrs = attributes.symbolize_keys

        # Filter by :only
        if config[:only]
          only_keys = Array(config[:only]).map(&:to_sym)
          attrs = attrs.slice(*only_keys)
        end

        # Filter by :except
        if config[:except]
          except_keys = Array(config[:except]).map(&:to_sym)
          attrs = attrs.except(*except_keys)
        end

        attrs
      end

      def build_validrb_context(context_config)
        case context_config
        when Proc
          result = context_config.call(self)
          result.is_a?(Validrb::Context) ? result : Validrb.context(**result)
        when Hash
          Validrb.context(**context_config)
        when Validrb::Context
          context_config
        else
          nil
        end
      end

      def build_filtered_schema(schema, config)
        # Apply :only filter - create a schema with only specified fields
        if config[:only]
          only_keys = Array(config[:only]).map(&:to_sym)
          schema = schema.pick(*only_keys)
        end

        # Apply :except filter - create a schema without specified fields
        if config[:except]
          except_keys = Array(config[:except]).map(&:to_sym)
          schema = schema.omit(*except_keys)
        end

        schema
      end
    end
  end
end
