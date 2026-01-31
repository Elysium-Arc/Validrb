# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Phase 4 Edge Cases" do
  describe "Literal Types Edge Cases" do
    it "handles nil as a literal value" do
      schema = Validrb.schema do
        field :status, :string, literal: [nil, "active"], nullable: true
      end

      result = schema.safe_parse({ status: nil })
      expect(result.success?).to be true
      expect(result.data[:status]).to be_nil
    end

    it "handles single literal value" do
      schema = Validrb.schema do
        field :constant, :string, literal: "FIXED"
      end

      result = schema.safe_parse({ constant: "FIXED" })
      expect(result.success?).to be true

      result = schema.safe_parse({ constant: "OTHER" })
      expect(result.failure?).to be true
    end

    it "handles symbol literals strictly (no coercion)" do
      schema = Validrb.schema do
        field :sym, :symbol, literal: [:active, :inactive]
      end

      # String won't match symbol literal
      result = schema.safe_parse({ sym: "active" })
      expect(result.failure?).to be true

      result = schema.safe_parse({ sym: :active })
      expect(result.success?).to be true
    end

    it "handles boolean literals" do
      schema = Validrb.schema do
        field :flag, :boolean, literal: [true]
      end

      result = schema.safe_parse({ flag: true })
      expect(result.success?).to be true

      result = schema.safe_parse({ flag: false })
      expect(result.failure?).to be true
    end

    it "handles float literals with precision" do
      schema = Validrb.schema do
        field :rate, :float, literal: [0.0, 0.5, 1.0]
      end

      result = schema.safe_parse({ rate: 0.5 })
      expect(result.success?).to be true

      result = schema.safe_parse({ rate: 0.51 })
      expect(result.failure?).to be true
    end

    it "literal combined with optional" do
      schema = Validrb.schema do
        field :mode, :string, literal: %w[fast slow], optional: true
      end

      result = schema.safe_parse({})
      expect(result.success?).to be true

      result = schema.safe_parse({ mode: "fast" })
      expect(result.success?).to be true

      result = schema.safe_parse({ mode: "medium" })
      expect(result.failure?).to be true
    end

    it "literal with default value" do
      schema = Validrb.schema do
        field :level, :integer, literal: [1, 2, 3], default: 1
      end

      result = schema.safe_parse({})
      expect(result.success?).to be true
      expect(result.data[:level]).to eq(1)
    end
  end

  describe "Refinements Edge Cases" do
    it "handles refinement that receives nil (with nullable)" do
      schema = Validrb.schema do
        field :value, :string, nullable: true,
              refine: ->(v) { v.nil? || v.length > 0 }
      end

      result = schema.safe_parse({ value: nil })
      expect(result.success?).to be true
    end

    it "handles refinement with exception (treated as failure)" do
      schema = Validrb.schema do
        field :data, :string,
              refine: ->(v) { v.unknown_method rescue false }
      end

      result = schema.safe_parse({ data: "test" })
      expect(result.failure?).to be true
    end

    it "handles all refinements failing with multiple messages" do
      schema = Validrb.schema do
        field :code, :string,
              refine: [
                { check: ->(v) { v.length >= 10 }, message: "too short" },
                { check: ->(v) { v.match?(/[A-Z]/) }, message: "needs uppercase" },
                { check: ->(v) { v.match?(/\d/) }, message: "needs digit" }
              ]
      end

      result = schema.safe_parse({ code: "ab" })
      expect(result.failure?).to be true
      # First failing refinement stops
      expect(result.errors.first.message).to eq("too short")
    end

    it "handles callable message in refinement" do
      schema = Validrb.schema do
        field :age, :integer,
              refine: {
                check: ->(v) { v >= 18 },
                message: ->(v) { "must be 18+, got #{v}" }
              }
      end

      result = schema.safe_parse({ age: 15 })
      expect(result.failure?).to be true
      expect(result.errors.first.message).to eq("must be 18+, got 15")
    end

    it "handles context being nil in context-aware refinement" do
      schema = Validrb.schema do
        field :amount, :decimal,
              refine: ->(v, ctx) { ctx.nil? || ctx[:limit].nil? || v <= ctx[:limit] }
      end

      # Without context
      result = schema.safe_parse({ amount: "99999" })
      expect(result.success?).to be true

      # With context
      result = schema.safe_parse({ amount: "100" }, context: { limit: 50 })
      expect(result.failure?).to be true
    end

    it "refinement runs after type coercion" do
      schema = Validrb.schema do
        field :count, :integer,
              refine: ->(v) { v.is_a?(Integer) && v > 0 }
      end

      # String gets coerced to integer before refinement
      result = schema.safe_parse({ count: "42" })
      expect(result.success?).to be true
    end

    it "refinement combined with preprocess" do
      schema = Validrb.schema do
        field :code, :string,
              preprocess: ->(v) { v.to_s.upcase },
              refine: ->(v) { v.match?(/\A[A-Z]+\z/) }
      end

      result = schema.safe_parse({ code: "abc" })
      expect(result.success?).to be true
      expect(result.data[:code]).to eq("ABC")
    end

    it "empty refinements array" do
      schema = Validrb.schema do
        field :value, :string, refine: []
      end

      result = schema.safe_parse({ value: "anything" })
      expect(result.success?).to be true
    end
  end

  describe "Validation Context Edge Cases" do
    it "handles deeply nested context data" do
      ctx = Validrb.context(
        user: { permissions: { can_edit: true, roles: [:admin] } }
      )

      schema = Validrb.schema do
        field :action, :string,
              refine: ->(v, c) {
                c[:user][:permissions][:can_edit] == true
              }
      end

      result = schema.safe_parse({ action: "edit" }, context: ctx)
      expect(result.success?).to be true
    end

    it "handles context with symbol and string key access" do
      ctx = Validrb.context(user_id: 123)

      expect(ctx[:user_id]).to eq(123)
      expect(ctx["user_id"]).to eq(123)
    end

    it "context is immutable" do
      ctx = Validrb.context(value: 1)
      expect(ctx).to be_frozen
      expect(ctx.data).to be_frozen
    end

    it "hash context gets converted to Context object" do
      schema = Validrb.schema do
        field :value, :integer,
              refine: ->(v, ctx) { ctx.is_a?(Validrb::Context) }
      end

      # Passing hash directly
      result = schema.safe_parse({ value: 1 }, context: { key: "val" })
      expect(result.success?).to be true
    end

    it "context available in transform" do
      schema = Validrb.schema do
        field :greeting, :string,
              transform: ->(v, ctx) {
                prefix = ctx&.fetch(:prefix, "Hello")
                "#{prefix}, #{v}!"
              }
      end

      result = schema.safe_parse({ greeting: "World" }, context: { prefix: "Hi" })
      expect(result.data[:greeting]).to eq("Hi, World!")
    end

    it "context available in preprocess" do
      schema = Validrb.schema do
        field :value, :string,
              preprocess: ->(v, ctx) {
                ctx&.fetch(:uppercase, false) ? v.to_s.upcase : v.to_s
              }
      end

      result = schema.safe_parse({ value: "test" }, context: { uppercase: true })
      expect(result.data[:value]).to eq("TEST")
    end

    it "context in nested object validation" do
      # Note: Context is NOT automatically passed to nested object schemas
      # This is by design - nested schemas are validated independently
      # The refinement sees nil context inside nested schema
      inner_schema = Validrb.schema do
        field :restricted, :boolean,
              refine: ->(v, ctx) { !v || (ctx && ctx[:is_admin]) }
      end

      schema = Validrb.schema do
        field :settings, :object, schema: inner_schema
      end

      # Non-admin trying to set restricted
      result = schema.safe_parse(
        { settings: { restricted: true } },
        context: { is_admin: false }
      )
      # Nested schema doesn't see outer context, so ctx is nil/empty
      # The refinement ->(v, ctx) { !v || (ctx && ctx[:is_admin]) }
      # evaluates to: !true || (empty_ctx && nil) = false || false = false
      # So this fails as expected behavior
      expect(result.failure?).to be true

      # Setting restricted to false should work
      result = schema.safe_parse(
        { settings: { restricted: false } },
        context: { is_admin: false }
      )
      expect(result.success?).to be true
    end

    it "empty context behaves correctly" do
      ctx = Validrb::Context.empty

      expect(ctx.empty?).to be true
      expect(ctx[:any_key]).to be_nil
      expect(ctx.key?(:any_key)).to be false
    end
  end

  describe "Schema Introspection Edge Cases" do
    it "introspects empty schema" do
      schema = Validrb.schema {}

      expect(schema.field_names).to eq([])
      expect(schema.required_fields).to eq([])
      expect(schema.optional_fields).to eq([])
    end

    it "introspects schema with all constraint types" do
      schema = Validrb.schema do
        field :full, :string,
              min: 1, max: 100,
              length: { min: 5, max: 50 },
              format: :email,
              enum: %w[a@b.com c@d.com]
      end

      field = schema.field(:full)
      values = field.constraint_values

      expect(values[:min]).to eq(1)
      expect(values[:max]).to eq(100)
      expect(values[:length]).to include(:min, :max)
      expect(values[:format]).to be_a(Regexp)
      expect(values[:enum]).to eq(%w[a@b.com c@d.com])
    end

    it "JSON schema for nullable field" do
      schema = Validrb.schema do
        field :value, :string, nullable: true
      end

      json_schema = schema.to_json_schema
      type = json_schema["properties"]["value"]["type"]
      expect(type).to include("string")
      expect(type).to include("null")
    end

    it "JSON schema for array with items" do
      schema = Validrb.schema do
        field :tags, :array, of: :string
      end

      json_schema = schema.to_json_schema
      expect(json_schema["properties"]["tags"]["type"]).to eq("array")
      expect(json_schema["properties"]["tags"]["items"]["type"]).to eq("string")
    end

    it "JSON schema for union type" do
      schema = Validrb.schema do
        field :id, :string, union: [:integer, :string]
      end

      json_schema = schema.to_json_schema
      expect(json_schema["properties"]["id"]["oneOf"]).to be_a(Array)
    end

    it "JSON schema for literal type" do
      schema = Validrb.schema do
        field :status, :string, literal: %w[a b c]
      end

      json_schema = schema.to_json_schema
      expect(json_schema["properties"]["status"]["enum"]).to eq(%w[a b c])
    end

    it "to_schema_hash includes all metadata" do
      schema = Validrb.schema(strict: true) do
        field :name, :string, optional: true, nullable: true
        validate { |_| }
      end

      hash = schema.to_schema_hash
      expect(hash[:fields][:name][:optional]).to be true
      expect(hash[:fields][:name][:nullable]).to be true
      expect(hash[:options][:strict]).to be true
      expect(hash[:validators_count]).to eq(1)
    end
  end

  describe "Custom Types Edge Cases" do
    after do
      # Cleanup any registered types
      %i[always_fails no_validation coerce_only complex_type].each do |type|
        Validrb::Types.registry.delete(type)
      end
    end

    it "custom type that always fails coercion" do
      Validrb.define_type(:always_fails) do
        coerce { |_| raise "Cannot coerce" }
      end

      schema = Validrb.schema do
        field :value, :always_fails
      end

      result = schema.safe_parse({ value: "anything" })
      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:type_error)
    end

    it "custom type with only coerce (no validation)" do
      Validrb.define_type(:coerce_only) do
        coerce { |v| v.to_s.reverse }
      end

      schema = Validrb.schema do
        field :value, :coerce_only
      end

      result = schema.safe_parse({ value: "hello" })
      expect(result.success?).to be true
      expect(result.data[:value]).to eq("olleh")
    end

    it "custom type used in array" do
      Validrb.define_type(:complex_type) do
        coerce { |v| v.to_s.upcase }
        validate { |v| v.length > 0 }
      end

      schema = Validrb.schema do
        field :items, :array, of: :complex_type
      end

      result = schema.safe_parse({ items: ["a", "b", "c"] })
      expect(result.success?).to be true
      expect(result.data[:items]).to eq(%w[A B C])
    end

    it "custom type handles nil gracefully" do
      Validrb.define_type(:no_validation) do
        coerce { |v| v&.to_s&.strip }
      end

      schema = Validrb.schema do
        field :value, :no_validation, nullable: true
      end

      result = schema.safe_parse({ value: nil })
      expect(result.success?).to be true
    end
  end

  describe "Discriminated Unions Edge Cases" do
    let(:type_a_schema) do
      Validrb.schema do
        field :type, :string
        field :value_a, :string
      end
    end

    let(:type_b_schema) do
      Validrb.schema do
        field :type, :string
        field :value_b, :integer
      end
    end

    it "handles symbol discriminator values" do
      # Create schemas that don't require 'type' field
      schema_a = Validrb.schema do
        field :kind, :string
        field :value_a, :string
      end

      schema_b = Validrb.schema do
        field :kind, :string
        field :value_b, :integer
      end

      type = Validrb::Types::DiscriminatedUnion.new(
        discriminator: :kind,
        mapping: {
          "a" => schema_a,
          "b" => schema_b
        }
      )

      # Symbol :a gets converted to string "a" for lookup
      value, errors = type.call({ kind: :a, value_a: "test" })
      expect(errors).to be_empty
      expect(value[:value_a]).to eq("test")
    end

    it "handles integer discriminator values" do
      schema_1 = Validrb.schema do
        field :code, :integer
        field :name, :string
      end

      schema_2 = Validrb.schema do
        field :code, :integer
        field :count, :integer
      end

      type = Validrb::Types::DiscriminatedUnion.new(
        discriminator: :code,
        mapping: {
          1 => schema_1,
          2 => schema_2
        }
      )

      value, errors = type.call({ code: 1, name: "test" })
      expect(errors).to be_empty

      value, errors = type.call({ code: 2, count: 42 })
      expect(errors).to be_empty
    end

    it "handles null discriminator value" do
      type = Validrb::Types::DiscriminatedUnion.new(
        discriminator: :type,
        mapping: { "a" => type_a_schema }
      )

      _value, errors = type.call({ type: nil, value_a: "test" })
      expect(errors).not_to be_empty
      expect(errors.first.code).to eq(:discriminator_missing)
    end

    it "handles non-hash input" do
      type = Validrb::Types::DiscriminatedUnion.new(
        discriminator: :type,
        mapping: { "a" => type_a_schema }
      )

      _value, errors = type.call("not a hash")
      expect(errors).not_to be_empty
      expect(errors.first.message).to include("object")
    end

    it "handles empty mapping gracefully" do
      type = Validrb::Types::DiscriminatedUnion.new(
        discriminator: :type,
        mapping: {}
      )

      _value, errors = type.call({ type: "anything" })
      expect(errors).not_to be_empty
      expect(errors.first.code).to eq(:invalid_discriminator)
    end

    it "propagates nested validation errors with correct paths" do
      nested_schema = Validrb.schema do
        field :type, :string
        field :nested, :object, schema: Validrb.schema {
          field :required_field, :string
        }
      end

      type = Validrb::Types::DiscriminatedUnion.new(
        discriminator: :type,
        mapping: { "nested" => nested_schema }
      )

      _value, errors = type.call({ type: "nested", nested: {} })
      expect(errors).not_to be_empty
      expect(errors.first.path).to include(:nested)
    end

    it "works as field in schema" do
      schema = Validrb.schema do
        field :data, :discriminated_union,
              discriminator: :type,
              mapping: {
                "text" => Validrb.schema {
                  field :type, :string
                  field :content, :string
                },
                "number" => Validrb.schema {
                  field :type, :string
                  field :value, :integer
                }
              }
      end

      result = schema.safe_parse({ data: { type: "text", content: "hello" } })
      expect(result.success?).to be true

      result = schema.safe_parse({ data: { type: "number", value: 42 } })
      expect(result.success?).to be true

      result = schema.safe_parse({ data: { type: "unknown" } })
      expect(result.failure?).to be true
    end
  end

  describe "Serialization Edge Cases" do
    it "serializes deeply nested structures" do
      data = {
        level1: {
          level2: {
            level3: {
              value: Date.new(2024, 1, 15)
            }
          }
        }
      }

      serialized = Validrb::Serializer.dump(data)
      expect(serialized["level1"]["level2"]["level3"]["value"]).to eq("2024-01-15")
    end

    it "serializes array of hashes" do
      data = {
        items: [
          { name: :first, date: Date.new(2024, 1, 1) },
          { name: :second, date: Date.new(2024, 2, 1) }
        ]
      }

      serialized = Validrb::Serializer.dump(data)
      expect(serialized["items"][0]["name"]).to eq("first")
      expect(serialized["items"][0]["date"]).to eq("2024-01-01")
    end

    it "serializes empty structures" do
      expect(Validrb::Serializer.dump({})).to eq({})
      expect(Validrb::Serializer.dump([])).to eq([])
    end

    it "handles special characters in strings" do
      data = { text: "Hello\n\"World\"\t\u0000" }
      json = Validrb::Serializer.dump(data, format: :json)
      expect { JSON.parse(json) }.not_to raise_error
    end

    it "serializes BigDecimal with full precision" do
      value = BigDecimal("123456789.123456789")
      serialized = Validrb::Serializer.dump(value)
      expect(serialized).to eq("123456789.123456789")
    end

    it "serializes Time with timezone" do
      time = Time.new(2024, 1, 15, 10, 30, 0, "+05:00")
      serialized = Validrb::Serializer.dump(time)
      expect(serialized).to include("2024-01-15")
    end

    it "serializes objects with to_h method" do
      obj = Struct.new(:name, :value).new("test", 42)
      serialized = Validrb::Serializer.dump(obj)
      expect(serialized["name"]).to eq("test")
      expect(serialized["value"]).to eq(42)
    end

    it "falls back to to_s for unknown types" do
      require "ostruct"
      obj = OpenStruct.new(name: "test")
      serialized = Validrb::Serializer.dump(obj)
      expect(serialized).to be_a(Hash)
    end

    it "schema dump with all types" do
      schema = Validrb.schema do
        field :string, :string
        field :integer, :integer
        field :float, :float
        field :boolean, :boolean
        field :date, :date
        field :datetime, :datetime
        field :decimal, :decimal
        field :array, :array, of: :string
      end

      result = schema.safe_parse({
        string: "text",
        integer: "42",
        float: "3.14",
        boolean: "true",
        date: "2024-01-15",
        datetime: "2024-01-15T10:30:00Z",
        decimal: "99.99",
        array: [:a, :b]
      })

      serialized = result.dump
      expect(serialized["string"]).to eq("text")
      expect(serialized["integer"]).to eq(42)
      expect(serialized["float"]).to eq(3.14)
      expect(serialized["boolean"]).to eq(true)
      expect(serialized["date"]).to eq("2024-01-15")
      expect(serialized["decimal"]).to eq("99.99")
      expect(serialized["array"]).to eq(["a", "b"])
    end

    it "failure dump includes all error details" do
      schema = Validrb.schema do
        field :a, :string
        field :b, :integer, min: 10
      end

      result = schema.safe_parse({ b: 5 })
      serialized = result.dump

      expect(serialized["errors"].size).to eq(2)
      error_paths = serialized["errors"].map { |e| e["path"] }
      expect(error_paths).to include(["a"])
      expect(error_paths).to include(["b"])
    end
  end

  describe "Combined Edge Cases" do
    it "literal + refinement + context" do
      schema = Validrb.schema do
        field :priority, :integer,
              literal: [1, 2, 3],
              refine: ->(v, ctx) { ctx.nil? || !ctx[:restricted] || v <= 2 }
      end

      # Normal mode - all priorities allowed
      result = schema.safe_parse({ priority: 3 })
      expect(result.success?).to be true

      # Restricted mode - priority 3 not allowed
      result = schema.safe_parse({ priority: 3 }, context: { restricted: true })
      expect(result.failure?).to be true
    end

    it "conditional + refinement + transform" do
      schema = Validrb.schema do
        field :needs_validation, :boolean, default: false
        field :code, :string,
              when: :needs_validation,
              preprocess: ->(v) { v.to_s.upcase },  # Uppercase BEFORE validation
              refine: ->(v) { v.match?(/\A[A-Z]{3}\d{3}\z/) }
      end

      # Condition false - no validation
      result = schema.safe_parse({ needs_validation: false })
      expect(result.success?).to be true

      # Condition true - validation applies (preprocess uppercases first)
      result = schema.safe_parse({ needs_validation: true, code: "abc123" })
      expect(result.success?).to be true
      expect(result.data[:code]).to eq("ABC123")

      # Condition true - invalid code (even after uppercase)
      result = schema.safe_parse({ needs_validation: true, code: "invalid" })
      expect(result.failure?).to be true
    end

    it "union + literal in discriminated union alternative" do
      text_schema = Validrb.schema do
        field :type, :string, literal: ["text"]
        field :content, :string
      end

      mixed_schema = Validrb.schema do
        field :type, :string, literal: ["mixed"]
        field :value, :string, union: [:integer, :string]
      end

      schema = Validrb.schema do
        field :item, :discriminated_union,
              discriminator: :type,
              mapping: {
                "text" => text_schema,
                "mixed" => mixed_schema
              }
      end

      result = schema.safe_parse({ item: { type: "mixed", value: 42 } })
      expect(result.success?).to be true
      expect(result.data[:item][:value]).to eq(42)

      result = schema.safe_parse({ item: { type: "mixed", value: "text" } })
      expect(result.success?).to be true
    end

    it "introspection of complex schema" do
      schema = Validrb.schema do
        field :id, :integer
        field :status, :string, literal: %w[a b], default: "a"
        field :data, :string, union: [:integer, :string], optional: true
        field :admin_field, :string, when: ->(d) { d[:role] == "admin" }
        field :validated, :string, refine: ->(v) { v.length > 0 }
      end

      expect(schema.field_names).to eq([:id, :status, :data, :admin_field, :validated])
      expect(schema.required_fields).to eq([:id, :validated])  # status has default, admin_field is conditional
      expect(schema.optional_fields).to eq([:data])
      expect(schema.conditional_fields).to eq([:admin_field])
      expect(schema.fields_with_defaults).to eq([:status])
    end

    it "serialization preserves transform output" do
      schema = Validrb.schema do
        field :tags, :string, transform: ->(v) { v.split(",").map(&:strip) }
      end

      result = schema.safe_parse({ tags: "a, b, c" })
      serialized = result.dump

      expect(serialized["tags"]).to eq(["a", "b", "c"])
    end

    it "full pipeline: preprocess -> coerce -> constraint -> refine -> transform -> serialize" do
      schema = Validrb.schema do
        field :amount, :decimal,
              preprocess: ->(v) { v.to_s.gsub(/[$,]/, "") },
              min: 0,
              refine: ->(v, ctx) { ctx.nil? || v <= ctx[:limit] },
              transform: ->(v) { v.round(2) }
      end

      result = schema.safe_parse(
        { amount: "$1,234.567" },
        context: { limit: 2000 }
      )

      expect(result.success?).to be true
      expect(result.data[:amount]).to eq(BigDecimal("1234.57"))

      serialized = result.dump
      expect(serialized["amount"]).to eq("1234.57")
    end
  end

  describe "Error Conditions" do
    it "invalid context type raises error" do
      schema = Validrb.schema do
        field :value, :string
      end

      expect {
        schema.safe_parse({ value: "test" }, context: "invalid")
      }.to raise_error(ArgumentError)
    end

    it "refinement with wrong arity still works" do
      schema = Validrb.schema do
        field :value, :string, refine: ->(v) { v.length > 0 }
      end

      # Single-arg refinement should work even with context passed
      result = schema.safe_parse({ value: "test" }, context: { key: "val" })
      expect(result.success?).to be true
    end

    it "handles very long literal arrays" do
      literals = (1..100).to_a
      schema = Validrb.schema do
        field :value, :integer, literal: literals
      end

      result = schema.safe_parse({ value: 50 })
      expect(result.success?).to be true

      result = schema.safe_parse({ value: 101 })
      expect(result.failure?).to be true
    end

    it "handles unicode in field values" do
      schema = Validrb.schema do
        field :name, :string, min: 1
        field :emoji, :string, literal: ["👍", "👎"]
      end

      result = schema.safe_parse({ name: "日本語", emoji: "👍" })
      expect(result.success?).to be true

      serialized = result.dump(format: :json)
      parsed = JSON.parse(serialized)
      expect(parsed["name"]).to eq("日本語")
      expect(parsed["emoji"]).to eq("👍")
    end
  end
end
