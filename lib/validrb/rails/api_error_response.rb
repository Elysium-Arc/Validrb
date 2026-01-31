# frozen_string_literal: true

module Validrb
  module Rails
    # API Error Response helpers for formatting validation errors
    #
    # Provides standardized error response formats for REST APIs,
    # including JSON:API and custom formats.
    #
    # @example Basic usage in controller
    #   class ApiController < ActionController::API
    #     include Validrb::Rails::ApiErrorResponse
    #
    #     rescue_from Validrb::Rails::Controller::ValidationError, with: :render_validation_error
    #   end
    #
    # @example Custom format
    #   render_validation_errors(result.errors, format: :jsonapi)
    #
    module ApiErrorResponse
      extend ActiveSupport::Concern

      # Error response formats
      FORMATS = %i[standard jsonapi simple detailed].freeze

      included do
        # Set default error format (can be overridden in controller)
        class_attribute :validrb_error_format, default: :standard
      end

      # Render validation errors as JSON response
      # @param errors [Validrb::ErrorCollection, Array<Validrb::Error>] The errors to render
      # @param status [Symbol, Integer] HTTP status code (default: :unprocessable_entity)
      # @param format [Symbol] Error format (:standard, :jsonapi, :simple, :detailed)
      def render_validation_errors(errors, status: :unprocessable_entity, format: nil)
        format ||= validrb_error_format
        body = format_errors(errors, format)
        render json: body, status: status
      end

      # Handle ValidationError exception
      # Suitable for use with rescue_from
      # @param exception [Controller::ValidationError] The validation exception
      def render_validation_error(exception)
        render_validation_errors(exception.errors)
      end

      # Format errors without rendering (useful for custom responses)
      # @param errors [Validrb::ErrorCollection, Array<Validrb::Error>] The errors
      # @param format [Symbol] Error format
      # @return [Hash] Formatted error hash
      def format_errors(errors, format = :standard)
        error_list = errors.respond_to?(:to_a) ? errors.to_a : Array(errors)

        case format
        when :standard
          format_standard(error_list)
        when :jsonapi
          format_jsonapi(error_list)
        when :simple
          format_simple(error_list)
        when :detailed
          format_detailed(error_list)
        else
          format_standard(error_list)
        end
      end

      private

      # Standard format: { errors: [{ field: "email", message: "..." }] }
      def format_standard(errors)
        {
          errors: errors.map do |error|
            {
              field: error.path.join("."),
              message: error.message,
              code: error.code
            }.compact
          end
        }
      end

      # JSON:API format: { errors: [{ source: { pointer: "/data/attributes/email" }, ... }] }
      def format_jsonapi(errors)
        {
          errors: errors.map do |error|
            pointer = jsonapi_pointer(error.path)
            {
              status: "422",
              source: { pointer: pointer },
              title: "Validation Error",
              detail: error.message,
              code: error.code
            }.compact
          end
        }
      end

      # Simple format: { errors: { email: ["is invalid"], name: ["is required"] } }
      def format_simple(errors)
        grouped = errors.group_by { |e| e.path.join(".") }
        {
          errors: grouped.transform_values { |errs| errs.map(&:message) }
        }
      end

      # Detailed format: includes path array, metadata
      def format_detailed(errors)
        {
          errors: errors.map do |error|
            {
              path: error.path,
              field: error.path.join("."),
              message: error.message,
              code: error.code,
              full_message: full_message_for(error)
            }.compact
          end,
          meta: {
            count: errors.size,
            timestamp: (defined?(Time.current) ? Time.current : Time.now).iso8601
          }
        }
      end

      def jsonapi_pointer(path)
        return "/data" if path.empty?

        parts = path.map do |part|
          case part
          when Integer
            part.to_s
          when Symbol, String
            part.to_s
          else
            part.to_s
          end
        end

        "/data/attributes/#{parts.join('/')}"
      end

      def full_message_for(error)
        field = error.path.last || "base"
        human_field = field.to_s.tr("_", " ").capitalize
        "#{human_field} #{error.message}"
      end
    end

    # Mixin for consistent error handling across controllers
    module ApiErrorHandler
      extend ActiveSupport::Concern

      included do
        include ApiErrorResponse

        rescue_from Validrb::Rails::Controller::ValidationError do |exception|
          render_validation_error(exception)
        end

        rescue_from Validrb::ValidationError do |exception|
          render_validation_errors(exception.errors)
        end
      end
    end
  end
end
