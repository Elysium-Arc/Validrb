# frozen_string_literal: true

module Validrb
  # Simple I18n module for error message translations
  # Can be configured to use Rails I18n or custom translations
  module I18n
    class << self
      attr_accessor :backend

      # Default English translations
      DEFAULT_TRANSLATIONS = {
        en: {
          required: "is required",
          type_error: "is invalid",
          min: "must be at least %{value}",
          min_length: "length must be at least %{value} (got %{actual})",
          max: "must be at most %{value}",
          max_length: "length must be at most %{value} (got %{actual})",
          length_exact: "length must be exactly %{value} (got %{actual})",
          length_range: "length must be between %{min} and %{max} (got %{actual})",
          format: "must match format %{pattern}",
          format_named: "must be a valid %{name}",
          enum: "must be one of: %{values}",
          unknown_key: "is not allowed",
          union_type_error: "must be one of the allowed types"
        }
      }.freeze

      # Current locale
      def locale
        @locale ||= :en
      end

      def locale=(loc)
        @locale = loc.to_sym
      end

      # Custom translations storage
      def translations
        @translations ||= deep_dup(DEFAULT_TRANSLATIONS)
      end

      # Add or override translations for a locale
      def add_translations(locale, trans)
        translations[locale.to_sym] ||= {}
        translations[locale.to_sym].merge!(trans)
      end

      # Translate a key with optional interpolations
      def t(key, **options)
        # If using Rails I18n backend
        if backend == :rails && defined?(::I18n)
          return ::I18n.t("validrb.errors.#{key}", **options, default: key.to_s)
        end

        # Use built-in translations
        message = translations.dig(locale, key) || translations.dig(:en, key) || key.to_s

        # Interpolate values
        options.each do |k, v|
          message = message.gsub("%{#{k}}", v.to_s)
        end

        message
      end

      # Reset to defaults
      def reset!
        @locale = :en
        @translations = deep_dup(DEFAULT_TRANSLATIONS)
        @backend = nil
      end

      # Configure the I18n module
      def configure
        yield self
      end

      private

      def deep_dup(hash)
        hash.transform_values do |v|
          v.is_a?(Hash) ? deep_dup(v) : v.dup
        end
      end
    end
  end
end
