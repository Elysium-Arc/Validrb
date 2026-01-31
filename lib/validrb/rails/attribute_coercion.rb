# frozen_string_literal: true

module Validrb
  module Rails
    # ActiveRecord Attribute Coercion using Validrb schemas
    #
    # Automatically coerces attribute values based on schema types
    # before saving to the database.
    #
    # @example Basic usage
    #   class User < ApplicationRecord
    #     include Validrb::Rails::AttributeCoercion
    #
    #     coerce_attributes_with do
    #       field :age, :integer
    #       field :active, :boolean
    #       field :balance, :decimal
    #       field :settings, :object do
    #         field :theme, :string, default: "light"
    #       end
    #     end
    #   end
    #
    #   user = User.new(age: "25", active: "yes", balance: "100.50")
    #   user.age     # => 25 (Integer)
    #   user.active  # => true (Boolean)
    #   user.balance # => #<BigDecimal:...> 100.5
    #
    # @example With existing schema
    #   class User < ApplicationRecord
    #     include Validrb::Rails::AttributeCoercion
    #
    #     coerce_attributes_with UserSchema, only: [:age, :active]
    #   end
    #
    module AttributeCoercion
      extend ActiveSupport::Concern

      class_methods do
        # Define attribute coercion schema
        # @param schema [Validrb::Schema, nil] Existing schema (optional)
        # @param only [Array<Symbol>] Only coerce these attributes
        # @param except [Array<Symbol>] Don't coerce these attributes
        # @yield Block defining the coercion schema
        def coerce_attributes_with(schema = nil, only: nil, except: nil, &block)
          if block_given?
            schema = Validrb.schema(&block)
          end

          raise ArgumentError, "Schema required" unless schema

          @validrb_coercion_config = {
            schema: schema,
            only: only,
            except: except
          }

          # Set up before_validation callback to coerce attributes
          before_validation :coerce_attributes_with_schema

          # Define attribute writers that coerce on assignment
          define_coercing_writers(schema, only: only, except: except)
        end

        def validrb_coercion_schema
          @validrb_coercion_config&.dig(:schema)
        end

        def validrb_coercion_config
          @validrb_coercion_config
        end

        private

        def define_coercing_writers(schema, only:, except:)
          schema.fields.each do |name, field|
            next if only && !only.include?(name)
            next if except && except.include?(name)

            # Create coercing writer that sets the instance variable directly
            define_method("#{name}=") do |value|
              coerced = coerce_single_attribute(name, value)
              instance_variable_set("@#{name}", coerced)
            end
          end
        end
      end

      # Coerce all schema attributes before validation
      def coerce_attributes_with_schema
        config = self.class.validrb_coercion_config
        return unless config

        schema = config[:schema]
        return unless schema

        # Get attributes to coerce
        attrs = coercion_attributes(config)

        # Parse through schema to coerce
        result = schema.safe_parse(attrs)

        # Apply coerced values back to model if successful
        if result.success?
          apply_coerced_attributes(result.data, config)
        end

        # Don't add errors here - let validates_with_schema handle that
        true
      end

      # Coerce a single attribute value
      # @param name [Symbol] Attribute name
      # @param value [Object] Raw value
      # @return [Object] Coerced value
      def coerce_single_attribute(name, value)
        config = self.class.validrb_coercion_config
        return value unless config

        schema = config[:schema]
        return value unless schema

        field = schema.fields[name]
        return value unless field

        # Try to coerce through the field's type
        type = field.instance_variable_get(:@type)
        return value unless type

        begin
          coerced = type.coerce(value)
          coerced == Validrb::Types::COERCION_FAILED ? value : coerced
        rescue StandardError
          value
        end
      end

      private

      def coercion_attributes(config)
        # Get current attribute values
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

      def apply_coerced_attributes(data, config)
        data.each do |name, value|
          next if config[:only] && !config[:only].include?(name)
          next if config[:except] && config[:except].include?(name)

          # Use write_attribute to bypass our coercing writer
          if respond_to?(:write_attribute, true)
            write_attribute(name, value)
          else
            instance_variable_set("@#{name}", value)
          end
        end
      end
    end
  end
end
