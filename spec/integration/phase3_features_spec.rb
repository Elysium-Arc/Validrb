# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Phase 3 Features Integration" do
  describe "preprocessing" do
    it "preprocesses value before type coercion" do
      schema = Validrb.schema do
        field :email, :string, format: :email, preprocess: ->(v) { v.to_s.strip.downcase }
      end

      result = schema.safe_parse({ email: "  USER@EXAMPLE.COM  " })
      expect(result.success?).to be true
      expect(result.data[:email]).to eq("user@example.com")
    end

    it "preprocesses before validation (allows format to pass)" do
      schema = Validrb.schema do
        field :code, :string, format: /\A[A-Z]+\z/, preprocess: ->(v) { v.upcase }
      end

      result = schema.safe_parse({ code: "abc" })
      expect(result.success?).to be true
      expect(result.data[:code]).to eq("ABC")
    end

    it "chains with transform (preprocess -> validate -> transform)" do
      schema = Validrb.schema do
        field :value, :integer,
              preprocess: ->(v) { v.to_s.gsub(/[^\d]/, "") },  # Remove non-digits
              transform: ->(v) { v * 2 }  # Double the result
      end

      result = schema.safe_parse({ value: "$100" })
      expect(result.success?).to be true
      expect(result.data[:value]).to eq(200)  # 100 * 2
    end

    it "preprocesses nil values" do
      schema = Validrb.schema do
        field :value, :string, nullable: true, preprocess: ->(v) { v&.strip }
      end

      result = schema.safe_parse({ value: nil })
      expect(result.success?).to be true
      expect(result.data[:value]).to be_nil
    end
  end

  describe "conditional validation (when:)" do
    it "validates field when condition is true" do
      schema = Validrb.schema do
        field :account_type, :string, enum: %w[personal business]
        field :company_name, :string, when: ->(data) { data[:account_type] == "business" }
      end

      # Business account requires company_name
      result = schema.safe_parse({ account_type: "business" })
      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:company_name])

      # Business account with company_name passes
      result = schema.safe_parse({ account_type: "business", company_name: "Acme Inc" })
      expect(result.success?).to be true

      # Personal account doesn't need company_name
      result = schema.safe_parse({ account_type: "personal" })
      expect(result.success?).to be true
      expect(result.data.key?(:company_name)).to be false
    end

    it "supports symbol condition (truthy field check)" do
      schema = Validrb.schema do
        field :subscribe, :boolean, default: false
        field :email, :string, format: :email, when: :subscribe
      end

      # Not subscribed - email not required
      result = schema.safe_parse({ subscribe: false })
      expect(result.success?).to be true

      # Subscribed - email required
      result = schema.safe_parse({ subscribe: true })
      expect(result.failure?).to be true

      # Subscribed with email
      result = schema.safe_parse({ subscribe: true, email: "user@example.com" })
      expect(result.success?).to be true
    end

    it "still processes value when condition is false but value is present" do
      schema = Validrb.schema do
        field :include_tax, :boolean, default: false
        field :tax_rate, :float,
              when: :include_tax,
              preprocess: ->(v) { v.to_s.gsub("%", "").to_f },
              transform: ->(v) { v / 100.0 }
      end

      # Condition false but value present - still transforms
      result = schema.safe_parse({ include_tax: false, tax_rate: "8.5%" })
      expect(result.success?).to be true
      expect(result.data[:tax_rate]).to eq(0.085)
    end
  end

  describe "conditional validation (unless:)" do
    it "validates field unless condition is true" do
      schema = Validrb.schema do
        field :use_default_address, :boolean, default: false
        field :address, :string, unless: :use_default_address
      end

      # Not using default - address required
      result = schema.safe_parse({ use_default_address: false })
      expect(result.failure?).to be true

      # Using default - address not required
      result = schema.safe_parse({ use_default_address: true })
      expect(result.success?).to be true
    end

    it "supports proc condition" do
      schema = Validrb.schema do
        field :role, :string
        field :admin_code, :string, unless: ->(data) { data[:role] == "guest" }
      end

      # Guest doesn't need admin_code
      result = schema.safe_parse({ role: "guest" })
      expect(result.success?).to be true

      # Admin needs admin_code
      result = schema.safe_parse({ role: "admin" })
      expect(result.failure?).to be true
    end
  end

  describe "combined when: and unless:" do
    it "requires both conditions to allow validation" do
      schema = Validrb.schema do
        field :is_premium, :boolean, default: false
        field :is_trial, :boolean, default: false
        field :payment_method, :string,
              when: :is_premium,
              unless: :is_trial
      end

      # Premium and not trial - payment required
      result = schema.safe_parse({ is_premium: true, is_trial: false })
      expect(result.failure?).to be true

      # Premium but trial - payment not required
      result = schema.safe_parse({ is_premium: true, is_trial: true })
      expect(result.success?).to be true

      # Not premium - payment not required
      result = schema.safe_parse({ is_premium: false })
      expect(result.success?).to be true
    end
  end

  describe "union types" do
    it "accepts any of the specified types" do
      # Note: Union tries types in order, put more specific types first
      schema = Validrb.schema do
        field :id, :string, union: [:integer, :string]
      end

      result = schema.safe_parse({ id: "abc-123" })
      expect(result.success?).to be true
      expect(result.data[:id]).to eq("abc-123")

      result = schema.safe_parse({ id: 12345 })
      expect(result.success?).to be true
      expect(result.data[:id]).to eq(12345)
    end

    it "reports error when no type matches" do
      schema = Validrb.schema do
        field :value, :string, union: [:integer, :boolean]
      end

      result = schema.safe_parse({ value: [1, 2, 3] })
      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:union_type_error)
    end

    it "works with complex types" do
      schema = Validrb.schema do
        field :date_or_string, :string, union: [:date, :string]
      end

      result = schema.safe_parse({ date_or_string: "2024-01-15" })
      expect(result.success?).to be true
      # Date type matches first
      expect(result.data[:date_or_string]).to be_a(Date)

      result = schema.safe_parse({ date_or_string: "not a date" })
      expect(result.success?).to be true
      expect(result.data[:date_or_string]).to eq("not a date")
    end
  end

  describe "coercion modes" do
    it "disables coercion when coerce: false" do
      schema = Validrb.schema do
        field :count, :integer, coerce: false
      end

      # Actual integer passes
      result = schema.safe_parse({ count: 42 })
      expect(result.success?).to be true

      # String fails (no coercion)
      result = schema.safe_parse({ count: "42" })
      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:type_error)
    end

    it "still validates constraints with coerce: false" do
      schema = Validrb.schema do
        field :age, :integer, coerce: false, min: 0
      end

      result = schema.safe_parse({ age: -5 })
      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:min)
    end

    it "enables coercion by default" do
      schema = Validrb.schema do
        field :count, :integer  # coerce: true is default
      end

      result = schema.safe_parse({ count: "42" })
      expect(result.success?).to be true
      expect(result.data[:count]).to eq(42)
    end
  end

  describe "I18n integration" do
    before do
      Validrb::I18n.reset!
    end

    after do
      Validrb::I18n.reset!
    end

    it "uses default English messages" do
      schema = Validrb.schema do
        field :name, :string
      end

      result = schema.safe_parse({})
      expect(result.errors.first.message).to eq("is required")
    end

    it "uses custom translations" do
      Validrb::I18n.add_translations(:en, required: "cannot be blank")

      schema = Validrb.schema do
        field :name, :string
      end

      result = schema.safe_parse({})
      expect(result.errors.first.message).to eq("cannot be blank")
    end

    it "supports multiple locales" do
      Validrb::I18n.add_translations(:es, required: "es requerido")
      Validrb::I18n.locale = :es

      schema = Validrb.schema do
        field :name, :string
      end

      result = schema.safe_parse({})
      expect(result.errors.first.message).to eq("es requerido")
    end
  end

  describe "real-world example: dynamic form" do
    let(:schema) do
      Validrb.schema do
        field :form_type, :string, enum: %w[contact support order]

        # Contact form fields
        field :name, :string, when: ->(d) { d[:form_type] == "contact" }
        field :email, :string, format: :email,
              preprocess: ->(v) { v&.strip&.downcase },
              when: ->(d) { %w[contact support].include?(d[:form_type]) }

        # Support form fields
        field :ticket_id, :string, format: /\ATKT-\d+\z/,
              when: ->(d) { d[:form_type] == "support" }
        field :priority, :integer, enum: [1, 2, 3], default: 2,
              when: ->(d) { d[:form_type] == "support" }

        # Order form fields
        field :order_id, :string, union: [:string, :integer],
              when: ->(d) { d[:form_type] == "order" }
        field :amount, :decimal, min: 0,
              preprocess: ->(v) { v.to_s.gsub(/[$,]/, "") },
              when: ->(d) { d[:form_type] == "order" }
      end
    end

    it "validates contact form" do
      result = schema.safe_parse({
        form_type: "contact",
        name: "John Doe",
        email: "  JOHN@EXAMPLE.COM  "
      })

      expect(result.success?).to be true
      expect(result.data[:email]).to eq("john@example.com")
      expect(result.data.key?(:ticket_id)).to be false
    end

    it "validates support form" do
      result = schema.safe_parse({
        form_type: "support",
        email: "user@example.com",
        ticket_id: "TKT-12345",
        priority: 1
      })

      expect(result.success?).to be true
      expect(result.data[:priority]).to eq(1)
    end

    it "validates order form" do
      result = schema.safe_parse({
        form_type: "order",
        order_id: 12345,
        amount: "$1,234.56"
      })

      expect(result.success?).to be true
      expect(result.data[:amount]).to eq(BigDecimal("1234.56"))
    end

    it "fails with missing conditional fields" do
      result = schema.safe_parse({
        form_type: "support"
        # Missing email and ticket_id
      })

      expect(result.failure?).to be true
      paths = result.errors.map(&:path)
      expect(paths).to include([:email])
      expect(paths).to include([:ticket_id])
    end
  end
end
