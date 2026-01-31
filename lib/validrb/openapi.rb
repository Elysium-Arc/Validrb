# frozen_string_literal: true

require "json"

module Validrb
  # OpenAPI 3.0 schema generation
  module OpenAPI
    class Generator
      attr_reader :schemas, :options

      def initialize(**options)
        @schemas = {}
        @options = options
        @component_schemas = {}
      end

      # Register a schema with a name for reuse
      def register(name, schema)
        @schemas[name.to_s] = schema
        self
      end

      # Generate a complete OpenAPI 3.0 document
      def generate(info:, servers: [], paths: {}, **extras)
        doc = {
          "openapi" => "3.0.3",
          "info" => normalize_info(info),
          "servers" => servers.map { |s| normalize_server(s) },
          "paths" => paths,
          "components" => {
            "schemas" => generate_component_schemas
          }
        }

        doc.merge!(extras.transform_keys(&:to_s))
        doc
      end

      # Generate OpenAPI schema for a single Validrb schema
      def schema_to_openapi(schema, name: nil)
        result = {
          "type" => "object",
          "properties" => {},
          "required" => []
        }

        schema.fields.each do |field_name, field|
          prop_schema = field_to_openapi(field)
          result["properties"][field_name.to_s] = prop_schema

          if field.required? && !field.conditional? && !field.has_default?
            result["required"] << field_name.to_s
          end
        end

        result.delete("required") if result["required"].empty?

        # Handle additionalProperties based on schema options
        if schema.options[:strict]
          result["additionalProperties"] = false
        elsif !schema.options[:passthrough]
          # Default: strip unknown keys (but don't enforce in schema)
          result["additionalProperties"] = false
        end

        result
      end

      # Generate component schemas from registered schemas
      def generate_component_schemas
        @schemas.transform_values { |s| schema_to_openapi(s) }
      end

      # Export as JSON
      def to_json(info:, **options)
        JSON.pretty_generate(generate(info: info, **options))
      end

      # Export as YAML (requires yaml to be loaded)
      def to_yaml(info:, **options)
        require "yaml"
        YAML.dump(generate(info: info, **options))
      end

      # ============================================================
      # Convenience Methods
      # ============================================================

      # Generate a request body structure for a schema
      # @param schema [Validrb::Schema] The schema to use
      # @param required [Boolean] Whether the request body is required (default: true)
      # @param content_type [String] The content type (default: "application/json")
      # @return [Hash] OpenAPI request body object
      def request_body(schema, required: true, content_type: "application/json")
        {
          "required" => required,
          "content" => {
            content_type => {
              "schema" => schema_to_openapi(schema)
            }
          }
        }
      end

      # Generate query parameters from a schema
      # @param schema [Validrb::Schema] The schema to convert to parameters
      # @return [Array<Hash>] Array of OpenAPI parameter objects
      def query_params(schema)
        schema.fields.map do |name, field|
          {
            "name" => name.to_s,
            "in" => "query",
            "required" => field.required? && !field.has_default? && !field.conditional?,
            "schema" => field_to_openapi(field)
          }
        end
      end

      # Generate path parameters from field names
      # @param names [Array<Symbol, String>] Parameter names
      # @param types [Hash] Optional type overrides { name: :integer }
      # @return [Array<Hash>] Array of OpenAPI parameter objects
      def path_params(*names, types: {})
        names.map do |name|
          type = types[name.to_sym] || :string
          {
            "name" => name.to_s,
            "in" => "path",
            "required" => true,
            "schema" => primitive_type_schema(type)
          }
        end
      end

      # Generate a response schema structure
      # @param schema [Validrb::Schema] The schema for the response
      # @param description [String] Response description
      # @param content_type [String] The content type (default: "application/json")
      # @return [Hash] OpenAPI response object
      def response_schema(schema, description: "Successful response", content_type: "application/json")
        {
          "description" => description,
          "content" => {
            content_type => {
              "schema" => schema_to_openapi(schema)
            }
          }
        }
      end

      # Generate a simple response without body
      # @param description [String] Response description
      # @return [Hash] OpenAPI response object
      def response(description)
        { "description" => description }
      end

      # Generate error response structure
      # @param description [String] Error description
      # @return [Hash] OpenAPI response object with standard error schema
      def error_response(description: "Validation error")
        {
          "description" => description,
          "content" => {
            "application/json" => {
              "schema" => {
                "type" => "object",
                "properties" => {
                  "error" => { "type" => "string" },
                  "details" => {
                    "type" => "array",
                    "items" => {
                      "type" => "object",
                      "properties" => {
                        "path" => { "type" => "string" },
                        "message" => { "type" => "string" }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      end

      private

      def primitive_type_schema(type)
        case type.to_sym
        when :string
          { "type" => "string" }
        when :integer
          { "type" => "integer" }
        when :float, :number
          { "type" => "number" }
        when :boolean
          { "type" => "boolean" }
        else
          { "type" => "string" }
        end
      end

      def normalize_info(info)
        info = info.transform_keys(&:to_s)
        {
          "title" => info["title"] || "API",
          "version" => info["version"] || "1.0.0",
          "description" => info["description"]
        }.compact
      end

      def normalize_server(server)
        case server
        when String
          { "url" => server }
        when Hash
          server.transform_keys(&:to_s)
        else
          { "url" => server.to_s }
        end
      end

      def field_to_openapi(field)
        schema = type_to_openapi(field.type)

        # Handle nullable
        if field.nullable?
          schema["nullable"] = true
        end

        # Handle default
        if field.has_default?
          default_val = field.default_value
          schema["default"] = serialize_default(default_val) unless default_val.is_a?(Proc)
        end

        # Handle constraints
        field.constraints.each do |constraint|
          apply_constraint(schema, constraint, field.type)
        end

        # Handle description from custom message
        # (We don't have a description field, but could use message as hint)

        schema
      end

      def type_to_openapi(type)
        case type
        when Types::String
          { "type" => "string" }
        when Types::Integer
          { "type" => "integer" }
        when Types::Float
          { "type" => "number", "format" => "float" }
        when Types::Decimal
          { "type" => "number", "format" => "double" }
        when Types::Boolean
          { "type" => "boolean" }
        when Types::Date
          { "type" => "string", "format" => "date" }
        when Types::DateTime
          { "type" => "string", "format" => "date-time" }
        when Types::Time
          { "type" => "string", "format" => "date-time" }
        when Types::Array
          schema = { "type" => "array" }
          if type.respond_to?(:item_type) && type.item_type
            schema["items"] = type_to_openapi(type.item_type)
          else
            schema["items"] = {}
          end
          schema
        when Types::Object
          if type.respond_to?(:schema) && type.schema
            schema_to_openapi(type.schema)
          else
            { "type" => "object" }
          end
        when Types::Union
          { "oneOf" => type.types.map { |t| type_to_openapi(t) } }
        when Types::Literal
          { "enum" => type.values }
        when Types::DiscriminatedUnion
          discriminator_schema = {
            "oneOf" => type.mapping.map do |disc_value, disc_schema|
              ref_or_inline = schema_to_openapi(disc_schema)
              ref_or_inline
            end,
            "discriminator" => {
              "propertyName" => type.discriminator.to_s,
              "mapping" => type.mapping.transform_values do |disc_schema|
                # In a full implementation, this would reference component schemas
                "#/components/schemas/inline"
              end
            }
          }
          # Simplify - just use oneOf without mapping for inline schemas
          { "oneOf" => type.mapping.values.map { |s| schema_to_openapi(s) } }
        else
          { "type" => "string" }
        end
      end

      def apply_constraint(schema, constraint, type)
        case constraint
        when Constraints::Min
          if numeric_type?(type)
            schema["minimum"] = constraint.value
          else
            schema["minLength"] = constraint.value
          end
        when Constraints::Max
          if numeric_type?(type)
            schema["maximum"] = constraint.value
          else
            schema["maxLength"] = constraint.value
          end
        when Constraints::Length
          opts = constraint.options
          schema["minLength"] = opts[:min] if opts[:min]
          schema["maxLength"] = opts[:max] if opts[:max]
          if opts[:exact]
            schema["minLength"] = opts[:exact]
            schema["maxLength"] = opts[:exact]
          end
          if opts[:range]
            schema["minLength"] = opts[:range].min
            schema["maxLength"] = opts[:range].max
          end
        when Constraints::Format
          if constraint.format_name
            case constraint.format_name
            when :email
              schema["format"] = "email"
            when :url
              schema["format"] = "uri"
            when :uuid
              schema["format"] = "uuid"
            when :phone
              schema["pattern"] = constraint.pattern.source
            else
              schema["pattern"] = constraint.pattern.source
            end
          else
            schema["pattern"] = constraint.pattern.source
          end
        when Constraints::Enum
          schema["enum"] = constraint.values
        end
      end

      def numeric_type?(type)
        type.is_a?(Types::Integer) ||
          type.is_a?(Types::Float) ||
          type.is_a?(Types::Decimal)
      end

      def serialize_default(value)
        case value
        when Date, DateTime, Time
          value.iso8601
        when BigDecimal
          value.to_f
        when Symbol
          value.to_s
        else
          value
        end
      end
    end

    # Create a path item for a schema
    class PathBuilder
      def initialize(generator)
        @generator = generator
        @paths = {}
      end

      # Add a POST endpoint that accepts a schema
      def post(path, schema:, summary: nil, description: nil, responses: nil, **options)
        @paths[path] ||= {}
        @paths[path]["post"] = build_operation(
          schema: schema,
          summary: summary,
          description: description,
          responses: responses,
          **options
        )
        self
      end

      # Add a PUT endpoint
      def put(path, schema:, summary: nil, description: nil, responses: nil, **options)
        @paths[path] ||= {}
        @paths[path]["put"] = build_operation(
          schema: schema,
          summary: summary,
          description: description,
          responses: responses,
          **options
        )
        self
      end

      # Add a PATCH endpoint
      def patch(path, schema:, summary: nil, description: nil, responses: nil, **options)
        @paths[path] ||= {}
        @paths[path]["patch"] = build_operation(
          schema: schema,
          summary: summary,
          description: description,
          responses: responses,
          **options
        )
        self
      end

      # Add a GET endpoint with query parameters from schema
      def get(path, schema: nil, summary: nil, description: nil, responses: nil, **options)
        @paths[path] ||= {}
        operation = {
          "summary" => summary,
          "description" => description,
          "responses" => responses || default_responses
        }.compact

        if schema
          operation["parameters"] = schema_to_parameters(schema)
        end

        operation.merge!(options.transform_keys(&:to_s))
        @paths[path]["get"] = operation
        self
      end

      def to_h
        @paths
      end

      private

      def build_operation(schema:, summary:, description:, responses:, **options)
        operation = {
          "summary" => summary,
          "description" => description,
          "requestBody" => {
            "required" => true,
            "content" => {
              "application/json" => {
                "schema" => @generator.schema_to_openapi(schema)
              }
            }
          },
          "responses" => responses || default_responses
        }.compact

        operation.merge!(options.transform_keys(&:to_s))
        operation
      end

      def schema_to_parameters(schema)
        schema.fields.map do |name, field|
          param = {
            "name" => name.to_s,
            "in" => "query",
            "required" => field.required? && !field.has_default?,
            "schema" => @generator.send(:field_to_openapi, field)
          }
          param
        end
      end

      def default_responses
        {
          "200" => {
            "description" => "Successful response"
          },
          "400" => {
            "description" => "Validation error"
          }
        }
      end
    end

    # Convenience method to create a generator
    def self.generator(**options)
      Generator.new(**options)
    end

    # Quick generation from a single schema
    def self.from_schema(schema, name: "Schema")
      generator = Generator.new
      generator.register(name, schema)
      generator
    end
  end

  # Add OpenAPI generation to Schema class
  class Schema
    # Generate OpenAPI 3.0 schema representation
    def to_openapi
      OpenAPI.from_schema(self).schema_to_openapi(self)
    end
  end

  module OpenAPI
    # Import OpenAPI/JSON Schema and create Validrb schemas
    class Importer
      attr_reader :definitions

      def initialize
        @definitions = {}
      end

      # Import from OpenAPI document
      def import_openapi(doc)
        doc = normalize_doc(doc)

        # Import component schemas
        if doc["components"] && doc["components"]["schemas"]
          doc["components"]["schemas"].each do |name, schema|
            @definitions[name] = import_schema(schema)
          end
        end

        # Also support older OpenAPI 2.0 definitions
        if doc["definitions"]
          doc["definitions"].each do |name, schema|
            @definitions[name] = import_schema(schema)
          end
        end

        self
      end

      # Import a single JSON Schema / OpenAPI schema object
      def import_schema(schema)
        schema = normalize_doc(schema)

        case schema["type"]
        when "object"
          import_object_schema(schema)
        when "array"
          import_array_schema(schema)
        else
          # For non-object schemas, wrap in a single-field schema
          Validrb.schema do
            field :value, import_type(schema)
          end
        end
      end

      # Get a specific imported schema by name
      def [](name)
        @definitions[name.to_s]
      end

      # List all imported schema names
      def schema_names
        @definitions.keys
      end

      private

      def normalize_doc(doc)
        case doc
        when String
          JSON.parse(doc)
        when Hash
          doc.transform_keys(&:to_s)
        else
          doc
        end
      end

      def import_object_schema(schema)
        properties = schema["properties"] || {}
        required_fields = Array(schema["required"])
        imported_props = {}

        properties.each do |name, prop_schema|
          imported_props[name] = {
            type: determine_type(prop_schema),
            options: extract_options(prop_schema, required_fields.include?(name))
          }
        end

        # Build the Validrb schema
        props = imported_props
        Validrb.schema do
          props.each do |name, config|
            field name.to_sym, config[:type], **config[:options]
          end
        end
      end

      def import_array_schema(schema)
        item_type = if schema["items"]
                      determine_type(schema["items"])
                    else
                      :string
                    end

        options = {}
        options[:min] = schema["minItems"] if schema["minItems"]
        options[:max] = schema["maxItems"] if schema["maxItems"]

        item_t = item_type
        opts = options
        Validrb.schema do
          field :items, :array, of: item_t, **opts
        end
      end

      def determine_type(schema)
        schema = schema.transform_keys(&:to_s) if schema.is_a?(Hash)

        # Handle oneOf / anyOf (union types)
        if schema["oneOf"] || schema["anyOf"]
          types = (schema["oneOf"] || schema["anyOf"]).map { |s| determine_type(s) }
          return types.first # Simplified - return first type
        end

        # Handle allOf (merge schemas) - simplified
        if schema["allOf"]
          return :object
        end

        # Handle $ref
        if schema["$ref"]
          ref_name = schema["$ref"].split("/").last
          return :object # Would need to resolve reference
        end

        # Handle enum
        if schema["enum"]
          return :string # Use enum constraint instead
        end

        type = schema["type"]
        format = schema["format"]

        case type
        when "string"
          case format
          when "date"
            :date
          when "date-time"
            :datetime
          when "time"
            :time
          when "uuid"
            :string # with uuid format constraint
          when "email"
            :string # with email format constraint
          when "uri", "url"
            :string # with url format constraint
          else
            :string
          end
        when "integer"
          :integer
        when "number"
          case format
          when "float"
            :float
          when "double"
            :decimal
          else
            :float
          end
        when "boolean"
          :boolean
        when "array"
          :array
        when "object"
          :object
        when "null"
          :string # Nullable will be handled separately
        else
          :string
        end
      end

      def extract_options(schema, is_required)
        schema = schema.transform_keys(&:to_s) if schema.is_a?(Hash)
        options = {}

        # Required / Optional
        options[:optional] = true unless is_required

        # Nullable
        if schema["nullable"] == true
          options[:nullable] = true
        end

        # Handle type array with null (JSON Schema nullable pattern)
        if schema["type"].is_a?(Array) && schema["type"].include?("null")
          options[:nullable] = true
        end

        # Default value
        if schema.key?("default")
          options[:default] = schema["default"]
        end

        # String constraints
        options[:min] = schema["minLength"] if schema["minLength"]
        options[:max] = schema["maxLength"] if schema["maxLength"]

        # Numeric constraints
        options[:min] = schema["minimum"] if schema["minimum"]
        options[:max] = schema["maximum"] if schema["maximum"]

        # Pattern
        if schema["pattern"]
          options[:format] = Regexp.new(schema["pattern"])
        end

        # Format (named formats)
        if schema["format"]
          case schema["format"]
          when "email"
            options[:format] = :email
          when "uri", "url"
            options[:format] = :url
          when "uuid"
            options[:format] = :uuid
          end
        end

        # Enum
        if schema["enum"]
          options[:enum] = schema["enum"]
        end

        options
      end

      def import_type(schema)
        determine_type(schema)
      end
    end

    # Convenience method to import from OpenAPI
    def self.import(doc)
      importer = Importer.new
      importer.import_openapi(doc)
      importer
    end

    # Import a single schema
    def self.import_schema(schema)
      Importer.new.import_schema(schema)
    end
  end
end
