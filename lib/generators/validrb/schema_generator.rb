# frozen_string_literal: true

require "rails/generators/named_base"

module Validrb
  module Generators
    class SchemaGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      desc "Generate a Validrb schema"

      def create_schema_file
        template "schema.rb.erb", "app/schemas/#{file_name}_schema.rb"
      end

      private

      def parsed_attributes
        attributes.map do |attr|
          parts = attr.split(":")
          name = parts[0]
          type = parts[1] || "string"
          options = parse_options(parts[2..] || [])

          {
            name: name,
            type: map_type(type),
            options: options
          }
        end
      end

      def map_type(type)
        case type.downcase
        when "string", "text"
          ":string"
        when "integer", "int", "bigint"
          ":integer"
        when "float", "double"
          ":float"
        when "decimal", "money"
          ":decimal"
        when "boolean", "bool"
          ":boolean"
        when "date"
          ":date"
        when "datetime", "timestamp"
          ":datetime"
        when "time"
          ":time"
        when "array"
          ":array"
        when "object", "hash", "json"
          ":object"
        when "email"
          ":string, format: :email"
        when "url"
          ":string, format: :url"
        when "uuid"
          ":string, format: :uuid"
        when "phone"
          ":string, format: :phone"
        else
          ":#{type}"
        end
      end

      def parse_options(opts)
        return "" if opts.empty?

        opts.map do |opt|
          case opt
          when "optional"
            "optional: true"
          when "nullable"
            "nullable: true"
          when /^min=(\d+)$/
            "min: #{::Regexp.last_match(1)}"
          when /^max=(\d+)$/
            "max: #{::Regexp.last_match(1)}"
          when /^default=(.+)$/
            value = ::Regexp.last_match(1)
            "default: #{value.match?(/^\d+$/) ? value : "\"#{value}\""}"
          else
            nil
          end
        end.compact.join(", ")
      end

      def schema_class_name
        "#{class_name}Schema"
      end
    end
  end
end
