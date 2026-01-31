# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Phase 4 Features Integration" do
  describe "literal types" do
    it "validates exact values with literal: option" do
      schema = Validrb.schema do
        field :status, :string, literal: %w[active pending]
      end

      result = schema.safe_parse({ status: "active" })
      expect(result.success?).to be true

      result = schema.safe_parse({ status: "unknown" })
      expect(result.failure?).to be true
    end

    it "works with numeric literals" do
      schema = Validrb.schema do
        field :priority, :integer, literal: [1, 2, 3]
      end

      result = schema.safe_parse({ priority: 2 })
      expect(result.success?).to be true

      result = schema.safe_parse({ priority: 5 })
      expect(result.failure?).to be true
    end
  end

  describe "refinements" do
    it "validates with refine: proc" do
      schema = Validrb.schema do
        field :age, :integer, refine: ->(v) { v >= 18 }
      end

      result = schema.safe_parse({ age: 21 })
      expect(result.success?).to be true

      result = schema.safe_parse({ age: 16 })
      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:refinement)
    end

    it "supports custom refinement messages" do
      schema = Validrb.schema do
        field :password, :string,
              refine: { check: ->(v) { v.length >= 8 }, message: "must be at least 8 characters" }
      end

      result = schema.safe_parse({ password: "short" })
      expect(result.failure?).to be true
      expect(result.errors.first.message).to eq("must be at least 8 characters")
    end

    it "supports multiple refinements" do
      schema = Validrb.schema do
        field :password, :string,
              refine: [
                { check: ->(v) { v.length >= 8 }, message: "must be at least 8 characters" },
                { check: ->(v) { v.match?(/[A-Z]/) }, message: "must contain uppercase letter" },
                { check: ->(v) { v.match?(/\d/) }, message: "must contain a digit" }
              ]
      end

      # All checks pass
      result = schema.safe_parse({ password: "SecurePass123" })
      expect(result.success?).to be true

      # Missing uppercase
      result = schema.safe_parse({ password: "securepass123" })
      expect(result.failure?).to be true
      expect(result.errors.first.message).to eq("must contain uppercase letter")
    end

    it "supports context-aware refinements" do
      schema = Validrb.schema do
        field :amount, :decimal,
              refine: ->(v, ctx) { ctx.nil? || ctx[:max_amount].nil? || v <= ctx[:max_amount] }
      end

      # Without context limit
      result = schema.safe_parse({ amount: "1000" })
      expect(result.success?).to be true

      # With context limit
      result = schema.safe_parse({ amount: "500" }, context: { max_amount: 1000 })
      expect(result.success?).to be true

      result = schema.safe_parse({ amount: "1500" }, context: { max_amount: 1000 })
      expect(result.failure?).to be true
    end
  end

  describe "validation context" do
    it "passes context to schema validators" do
      schema = Validrb.schema do
        field :role, :string

        validate do |data, ctx|
          if data[:role] == "admin" && ctx && !ctx[:user_is_superadmin]
            error(:role, "cannot assign admin role")
          end
        end
      end

      # Normal user can't assign admin
      result = schema.safe_parse({ role: "admin" }, context: { user_is_superadmin: false })
      expect(result.failure?).to be true

      # Superadmin can assign admin
      result = schema.safe_parse({ role: "admin" }, context: { user_is_superadmin: true })
      expect(result.success?).to be true
    end

    it "passes context to conditional validation" do
      schema = Validrb.schema do
        field :premium_feature, :boolean,
              when: ->(data, ctx) { ctx && ctx[:is_premium_user] }
      end

      # Non-premium user - field not required
      result = schema.safe_parse({}, context: { is_premium_user: false })
      expect(result.success?).to be true

      # Premium user - field required
      result = schema.safe_parse({}, context: { is_premium_user: true })
      expect(result.failure?).to be true
    end

    it "passes context to transforms" do
      schema = Validrb.schema do
        field :greeting, :string,
              transform: ->(v, ctx) { ctx && ctx[:locale] == :es ? "Hola, #{v}" : "Hello, #{v}" }
      end

      result = schema.safe_parse({ greeting: "World" }, context: { locale: :en })
      expect(result.data[:greeting]).to eq("Hello, World")

      result = schema.safe_parse({ greeting: "World" }, context: { locale: :es })
      expect(result.data[:greeting]).to eq("Hola, World")
    end

    it "creates context via Validrb.context" do
      ctx = Validrb.context(user_id: 123, locale: :en)
      expect(ctx).to be_a(Validrb::Context)
      expect(ctx[:user_id]).to eq(123)
    end
  end

  describe "discriminated unions" do
    let(:payment_schema) do
      credit_card = Validrb.schema do
        field :method, :string
        field :card_number, :string
        field :expiry, :string
      end

      paypal = Validrb.schema do
        field :method, :string
        field :email, :string, format: :email
      end

      bank_transfer = Validrb.schema do
        field :method, :string
        field :account_number, :string
        field :routing_number, :string
      end

      Validrb.schema do
        field :payment, :discriminated_union,
              discriminator: :method,
              mapping: {
                "credit_card" => credit_card,
                "paypal" => paypal,
                "bank_transfer" => bank_transfer
              }
      end
    end

    it "validates based on discriminator field" do
      result = payment_schema.safe_parse({
        payment: {
          method: "credit_card",
          card_number: "4111111111111111",
          expiry: "12/25"
        }
      })
      expect(result.success?).to be true

      result = payment_schema.safe_parse({
        payment: {
          method: "paypal",
          email: "user@example.com"
        }
      })
      expect(result.success?).to be true
    end

    it "fails when discriminator is invalid" do
      result = payment_schema.safe_parse({
        payment: {
          method: "bitcoin",
          wallet: "abc123"
        }
      })
      expect(result.failure?).to be true
    end

    it "validates required fields for selected schema" do
      result = payment_schema.safe_parse({
        payment: {
          method: "bank_transfer",
          account_number: "12345"
          # Missing routing_number
        }
      })
      expect(result.failure?).to be true
    end
  end

  describe "custom types" do
    before do
      Validrb.define_type(:money) do
        name "money"
        coerce { |v| BigDecimal(v.to_s.gsub(/[$,]/, "")) }
        validate { |v| v >= 0 }
        error_message { |v| "must be a valid non-negative money amount" }
      end
    end

    after do
      Validrb::Types.registry.delete(:money)
    end

    it "uses custom type in schema" do
      schema = Validrb.schema do
        field :price, :money
      end

      result = schema.safe_parse({ price: "$1,234.56" })
      expect(result.success?).to be true
      expect(result.data[:price]).to eq(BigDecimal("1234.56"))
    end

    it "validates with custom type rules" do
      schema = Validrb.schema do
        field :price, :money
      end

      result = schema.safe_parse({ price: "-50" })
      expect(result.failure?).to be true
    end
  end

  describe "schema introspection" do
    let(:schema) do
      Validrb.schema do
        field :id, :integer
        field :name, :string, min: 1, max: 100
        field :email, :string, format: :email, optional: true
      end
    end

    it "lists all fields" do
      expect(schema.field_names).to eq([:id, :name, :email])
    end

    it "provides field details" do
      field = schema.field(:name)
      expect(field.type.type_name).to eq("string")
      expect(field.constraint_values[:min]).to eq(1)
      expect(field.constraint_values[:max]).to eq(100)
    end

    it "generates JSON Schema" do
      json_schema = schema.to_json_schema
      expect(json_schema["type"]).to eq("object")
      expect(json_schema["properties"]["name"]["type"]).to eq("string")
      expect(json_schema["required"]).to eq(["id", "name"])
    end
  end

  describe "serialization" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
        field :created_at, :date
        field :amount, :decimal
        field :tags, :array, of: :string
      end
    end

    it "serializes to hash with primitives" do
      result = schema.safe_parse({
        name: "Test",
        created_at: "2024-01-15",
        amount: "99.99",
        tags: [:ruby, :validation]
      })

      serialized = result.dump
      expect(serialized["name"]).to eq("Test")
      expect(serialized["created_at"]).to eq("2024-01-15")
      expect(serialized["amount"]).to eq("99.99")
      expect(serialized["tags"]).to eq(["ruby", "validation"])
    end

    it "serializes to JSON" do
      result = schema.safe_parse({
        name: "Test",
        created_at: "2024-01-15",
        amount: "100",
        tags: ["a"]
      })

      json = result.to_json
      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed["name"]).to eq("Test")
    end

    it "serializes failures to error format" do
      result = schema.safe_parse({})
      expect(result.failure?).to be true

      serialized = result.dump
      expect(serialized["errors"]).to be_a(Array)
      expect(serialized["errors"].first["path"]).to eq(["name"])
    end
  end

  describe "real-world example: API request validation" do
    before do
      Validrb.define_type(:slug) do
        coerce { |v| v.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "") }
        validate { |v| v.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) }
      end
    end

    after do
      Validrb::Types.registry.delete(:slug)
    end

    let(:create_post_schema) do
      Validrb.schema do
        field :title, :string, min: 1, max: 200
        field :slug, :slug
        field :content, :string, min: 10
        field :status, :string, literal: %w[draft published archived]
        field :author_id, :integer,
              refine: ->(id, ctx) { ctx.nil? || ctx[:allowed_authors].nil? || ctx[:allowed_authors].include?(id) }
        field :tags, :array, of: :string, optional: true, default: []
        field :published_at, :datetime,
              when: ->(data) { data[:status] == "published" }
      end
    end

    it "validates complete request" do
      ctx = Validrb.context(
        allowed_authors: [1, 2, 3],
        current_user_id: 1
      )

      result = create_post_schema.safe_parse({
        title: "Hello World",
        slug: "Hello World!",
        content: "This is my first blog post with enough content.",
        status: "published",
        author_id: 1,
        tags: ["ruby", "validation"],
        published_at: "2024-01-15T10:00:00Z"
      }, context: ctx)

      expect(result.success?).to be true
      expect(result.data[:slug]).to eq("hello-world")
      expect(result.data[:tags]).to eq(["ruby", "validation"])
    end

    it "validates draft without published_at" do
      result = create_post_schema.safe_parse({
        title: "Draft Post",
        slug: "draft-post",
        content: "This is a draft post with enough content.",
        status: "draft",
        author_id: 1
      })

      expect(result.success?).to be true
      expect(result.data.key?(:published_at)).to be false
    end

    it "requires published_at for published posts" do
      result = create_post_schema.safe_parse({
        title: "Published Post",
        slug: "published-post",
        content: "This is a published post with enough content.",
        status: "published",
        author_id: 1
      })

      expect(result.failure?).to be true
      expect(result.errors.any? { |e| e.path == [:published_at] }).to be true
    end

    it "validates author against allowed list" do
      ctx = Validrb.context(allowed_authors: [1, 2])

      result = create_post_schema.safe_parse({
        title: "Test",
        slug: "test",
        content: "Content with enough length here.",
        status: "draft",
        author_id: 999
      }, context: ctx)

      expect(result.failure?).to be true
      expect(result.errors.any? { |e| e.path == [:author_id] }).to be true
    end

    it "serializes for API response" do
      result = create_post_schema.safe_parse({
        title: "API Test",
        slug: "api-test",
        content: "Testing the full API workflow.",
        status: "draft",
        author_id: 1
      })

      json = result.to_json
      parsed = JSON.parse(json)
      expect(parsed["title"]).to eq("API Test")
      expect(parsed["slug"]).to eq("api-test")
    end
  end
end
