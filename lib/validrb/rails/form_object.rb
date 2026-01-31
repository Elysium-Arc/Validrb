# frozen_string_literal: true

require "active_model"

module Validrb
  module Rails
    # A form object that wraps a Validrb schema for use with Rails forms
    #
    # @example Basic usage
    #   class UserForm < Validrb::Rails::FormObject
    #     schema do
    #       field :name, :string, min: 2
    #       field :email, :string, format: :email
    #       field :age, :integer, optional: true
    #     end
    #   end
    #
    #   form = UserForm.new(name: "John", email: "john@example.com")
    #   form.valid?  # => true
    #   form.name    # => "John"
    #
    # @example In controllers
    #   def create
    #     @user_form = UserForm.new(user_params)
    #     if @user_form.valid?
    #       User.create!(@user_form.attributes)
    #       redirect_to users_path
    #     else
    #       render :new
    #     end
    #   end
    #
    # @example With form helpers
    #   <%= form_with model: @user_form do |f| %>
    #     <%= f.text_field :name %>
    #     <%= f.email_field :email %>
    #     <%= f.submit %>
    #   <% end %>
    #
    class FormObject
      include ActiveModel::Model
      include ActiveModel::Validations

      class << self
        attr_reader :validrb_schema, :validrb_field_names

        # Define the schema for this form object
        # @yield Block defining the schema fields
        def schema(**options, &block)
          @validrb_schema = Validrb.schema(**options, &block)
          define_attribute_methods
        end

        # Use an existing schema
        # @param schema [Validrb::Schema] The schema to use
        def use_schema(schema)
          @validrb_schema = schema
          define_attribute_methods
        end

        # Get the model name for Rails form helpers
        def model_name
          @model_name ||= ActiveModel::Name.new(self, nil, name&.demodulize&.delete_suffix("Form") || "Form")
        end

        private

        def define_attribute_methods
          return unless @validrb_schema

          @validrb_field_names = []

          @validrb_schema.fields.each do |name, _field|
            @validrb_field_names << name
            # Define simple attr_accessor for each field
            attr_accessor name
          end
        end
      end

      # Initialize with attributes hash
      # @param attributes [Hash] Initial attribute values
      def initialize(attributes = {})
        @raw_attributes = normalize_attributes(attributes)
        @validated = false
        @validation_result = nil

        # Call super first to initialize ActiveModel
        super()

        # Set initial values
        @raw_attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      # Validate using the Validrb schema
      def valid?(context = nil)
        return super if self.class.validrb_schema.nil?

        @validation_result = self.class.validrb_schema.safe_parse(@raw_attributes)
        @validated = true

        if @validation_result.failure?
          ErrorConverter.add_to_active_model(@validation_result.errors, errors)
          false
        else
          # Update attributes with coerced/transformed values
          @validation_result.data.each do |key, value|
            send("#{key}=", value) if respond_to?("#{key}=")
          end
          true
        end
      end

      # Check if validation has been run
      def validated?
        @validated
      end

      # Get the validation result
      # @return [Validrb::Result, nil]
      def validation_result
        @validation_result
      end

      # Get validated and coerced attributes
      # @return [Hash]
      def attributes
        if @validation_result&.success?
          @validation_result.data
        else
          # Return current attribute values
          field_names = self.class.validrb_field_names || []
          field_names.each_with_object({}) do |name, hash|
            hash[name] = send(name)
          end
        end
      end

      # Get validated attributes (alias for Rails compatibility)
      def to_h
        attributes
      end

      # Persisted? is required by Rails form helpers
      def persisted?
        false
      end

      # Required by Rails form helpers for new records
      def new_record?
        true
      end

      # Convert to params-safe hash
      def to_params
        attributes.transform_keys(&:to_s)
      end

      private

      def normalize_attributes(attrs)
        case attrs
        when ActionController::Parameters
          attrs.to_unsafe_h.transform_keys(&:to_sym)
        when Hash
          attrs.transform_keys(&:to_sym)
        else
          {}
        end
      rescue NameError
        # ActionController::Parameters not available (not in Rails)
        attrs.is_a?(Hash) ? attrs.transform_keys(&:to_sym) : {}
      end
    end
  end
end
