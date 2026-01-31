# frozen_string_literal: true

module Validrb
  module Rails
    # Converts Validrb errors to ActiveModel::Errors format
    module ErrorConverter
      module_function

      # Convert Validrb errors to a hash suitable for ActiveModel::Errors
      # @param errors [Validrb::ErrorCollection, Array<Validrb::Error>] The errors to convert
      # @return [Hash] Hash of attribute => [messages]
      def to_hash(errors)
        error_list = errors.respond_to?(:to_a) ? errors.to_a : errors
        result = Hash.new { |h, k| h[k] = [] }

        error_list.each do |error|
          attribute = error_attribute(error.path)
          result[attribute] << error.message
        end

        result
      end

      # Add Validrb errors to an ActiveModel::Errors object
      # @param errors [Validrb::ErrorCollection, Array<Validrb::Error>] The Validrb errors
      # @param active_model_errors [ActiveModel::Errors] The target errors object
      def add_to_active_model(errors, active_model_errors)
        to_hash(errors).each do |attribute, messages|
          messages.each do |message|
            active_model_errors.add(attribute, message)
          end
        end
      end

      # Convert error path to attribute name
      # [:user, :address, :city] => :"user.address.city"
      # [:name] => :name
      # [] => :base
      def error_attribute(path)
        return :base if path.empty?
        return path.first if path.length == 1

        # For nested paths, join with dots (Rails nested attributes style)
        path.map(&:to_s).join(".").to_sym
      end
    end
  end
end
