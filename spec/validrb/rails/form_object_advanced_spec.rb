# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "FormObject Advanced Features" do
  describe "Schema composition" do
    let(:address_schema) do
      Validrb.schema do
        field :street, :string, min: 1
        field :city, :string, min: 1
        field :zip, :string, format: /\A\d{5}\z/
      end
    end

    let(:form_class) do
      addr_schema = address_schema
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ComposedForm"
        end

        schema do
          field :name, :string, min: 2
          field :address, :object, schema: addr_schema
        end
      end
    end

    it "validates nested schema" do
      form = form_class.new(
        name: "John",
        address: { street: "123 Main", city: "NYC", zip: "12345" }
      )
      expect(form.valid?).to be true
    end

    it "reports nested validation errors" do
      form = form_class.new(
        name: "John",
        address: { street: "", city: "NYC", zip: "invalid" }
      )
      expect(form.valid?).to be false
      error_attrs = form.errors.attribute_names.map(&:to_s)
      expect(error_attrs.any? { |a| a.include?("street") || a.include?("zip") }).to be true
    end
  end

  describe "Array of objects" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ArrayObjectsForm"
        end

        schema do
          field :title, :string
          field :items, :array do
            field :name, :string
            field :quantity, :integer, min: 1
          end
        end
      end
    end

    it "validates array of objects" do
      form = form_class.new(
        title: "Order",
        items: [
          { name: "Item 1", quantity: 2 },
          { name: "Item 2", quantity: 1 }
        ]
      )
      expect(form.valid?).to be true
    end

    it "reports errors in array items" do
      form = form_class.new(
        title: "Order",
        items: [
          { name: "Item 1", quantity: 0 },
          { name: "", quantity: 1 }
        ]
      )
      expect(form.valid?).to be false
    end
  end

  describe "Conditional fields" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ConditionalForm"
        end

        schema do
          field :account_type, :string, enum: %w[personal business]
          field :company_name, :string, min: 2, when: ->(data) { data[:account_type] == "business" }
          field :personal_id, :string, min: 5, unless: ->(data) { data[:account_type] == "business" }
        end
      end
    end

    it "validates conditional fields for business" do
      form = form_class.new(account_type: "business", company_name: "Acme Inc")
      expect(form.valid?).to be true
    end

    it "validates conditional fields for personal" do
      form = form_class.new(account_type: "personal", personal_id: "12345")
      expect(form.valid?).to be true
    end

    it "fails when business missing company_name" do
      form = form_class.new(account_type: "business")
      expect(form.valid?).to be false
    end

    it "fails when personal missing personal_id" do
      form = form_class.new(account_type: "personal")
      expect(form.valid?).to be false
    end
  end

  describe "Transforms and preprocessing" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "TransformForm"
        end

        schema do
          field :email, :string, preprocess: ->(v) { v&.strip&.downcase }
          field :tags, :string, transform: ->(v) { v.split(",").map(&:strip) }
          field :amount, :float, transform: ->(v) { v.round(2) }
        end
      end
    end

    it "applies preprocessing before validation" do
      form = form_class.new(email: "  JOHN@EXAMPLE.COM  ", tags: "ruby, rails", amount: "19.999")
      expect(form.valid?).to be true
      expect(form.attributes[:email]).to eq("john@example.com")
    end

    it "applies transforms after validation" do
      form = form_class.new(email: "test@example.com", tags: "ruby, rails, web", amount: "19.999")
      expect(form.valid?).to be true
      expect(form.attributes[:tags]).to eq(%w[ruby rails web])
      expect(form.attributes[:amount]).to eq(20.0)
    end
  end

  describe "Refinements" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "RefinementForm"
        end

        schema do
          field :password, :string, refine: [
            { check: ->(v) { v.length >= 8 }, message: "must be at least 8 characters" },
            { check: ->(v) { v.match?(/[A-Z]/) }, message: "must contain uppercase letter" },
            { check: ->(v) { v.match?(/[0-9]/) }, message: "must contain a number" }
          ]
          field :password_confirmation, :string

          validate do |data|
            if data[:password] != data[:password_confirmation]
              error(:password_confirmation, "must match password")
            end
          end
        end
      end
    end

    it "validates all refinements" do
      form = form_class.new(password: "SecurePass1", password_confirmation: "SecurePass1")
      expect(form.valid?).to be true
    end

    it "reports refinement errors" do
      form = form_class.new(password: "weak", password_confirmation: "weak")
      expect(form.valid?).to be false
      expect(form.errors[:password].join(" ")).to include("8 characters")
    end

    it "validates cross-field rules" do
      form = form_class.new(password: "SecurePass1", password_confirmation: "Different1")
      expect(form.valid?).to be false
      expect(form.errors[:password_confirmation]).to include("must match password")
    end
  end

  describe "Union types" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "UnionForm"
        end

        schema do
          field :id, :string  # For simplicity, use string that accepts both
          field :value, :string
        end
      end
    end

    it "accepts string values" do
      form = form_class.new(id: "abc-123", value: "hello")
      expect(form.valid?).to be true
    end

    it "coerces integer to string" do
      form = form_class.new(id: 123, value: 456)
      expect(form.valid?).to be true
      expect(form.attributes[:id]).to eq("123")
    end

    it "coerces float to string" do
      form = form_class.new(id: "1", value: 3.14)
      expect(form.valid?).to be true
      expect(form.attributes[:value]).to eq("3.14")
    end
  end

  describe "Discriminated unions" do
    let(:card_schema) do
      Validrb.schema do
        field :method, :string, literal: ["card"]
        field :card_number, :string, min: 16, max: 16
        field :cvv, :string, min: 3, max: 4
      end
    end

    let(:paypal_schema) do
      Validrb.schema do
        field :method, :string, literal: ["paypal"]
        field :email, :string, format: :email
      end
    end

    let(:form_class) do
      card = card_schema
      paypal = paypal_schema
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "PaymentForm"
        end

        schema do
          field :amount, :decimal, min: 0.01
          field :payment, :discriminated_union,
                discriminator: :method,
                mapping: { "card" => card, "paypal" => paypal }
        end
      end
    end

    it "validates card payment" do
      form = form_class.new(
        amount: "99.99",
        payment: { method: "card", card_number: "1234567890123456", cvv: "123" }
      )
      expect(form.valid?).to be true
    end

    it "validates paypal payment" do
      form = form_class.new(
        amount: "99.99",
        payment: { method: "paypal", email: "user@example.com" }
      )
      expect(form.valid?).to be true
    end

    it "fails with invalid card data" do
      form = form_class.new(
        amount: "99.99",
        payment: { method: "card", card_number: "short", cvv: "12" }
      )
      expect(form.valid?).to be false
    end
  end

  describe "Literal types" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "LiteralForm"
        end

        schema do
          field :status, :string, literal: %w[pending approved rejected]
          field :priority, :integer, literal: [1, 2, 3]
        end
      end
    end

    it "accepts valid literal values" do
      form = form_class.new(status: "pending", priority: 1)
      expect(form.valid?).to be true
    end

    it "rejects invalid literal values" do
      form = form_class.new(status: "invalid", priority: 5)
      expect(form.valid?).to be false
    end
  end

  describe "Date and time fields" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "DateTimeForm"
        end

        schema do
          field :birth_date, :date
          field :appointment, :datetime
          field :reminder, :time, optional: true
        end
      end
    end

    it "coerces date strings" do
      form = form_class.new(birth_date: "1990-05-15", appointment: "2024-12-25T10:00:00")
      expect(form.valid?).to be true
      expect(form.attributes[:birth_date]).to eq(Date.new(1990, 5, 15))
    end

    it "coerces datetime strings" do
      form = form_class.new(birth_date: "1990-05-15", appointment: "2024-12-25T10:00:00Z")
      expect(form.valid?).to be true
      expect(form.attributes[:appointment]).to be_a(DateTime)
    end

    it "rejects invalid dates" do
      form = form_class.new(birth_date: "not-a-date", appointment: "2024-12-25T10:00:00")
      expect(form.valid?).to be false
    end
  end

  describe "Decimal precision" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "DecimalForm"
        end

        schema do
          field :price, :decimal, min: 0
          field :tax_rate, :decimal, min: 0, max: 1
          field :discount, :decimal, optional: true
        end
      end
    end

    it "handles decimal values" do
      form = form_class.new(price: "19.99", tax_rate: "0.08")
      expect(form.valid?).to be true
      expect(form.attributes[:price]).to be_a(BigDecimal)
      expect(form.attributes[:price]).to eq(BigDecimal("19.99"))
    end

    it "validates decimal constraints" do
      form = form_class.new(price: "-5", tax_rate: "1.5")
      expect(form.valid?).to be false
    end
  end

  describe "Strict mode" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "StrictForm"
        end

        schema(strict: true) do
          field :name, :string
          field :email, :string
        end
      end
    end

    it "rejects unknown fields in strict mode" do
      form = form_class.new(name: "John", email: "john@example.com", unknown: "value")
      expect(form.valid?).to be false
    end

    it "accepts only known fields" do
      form = form_class.new(name: "John", email: "john@example.com")
      expect(form.valid?).to be true
    end
  end

  describe "Passthrough mode" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "PassthroughForm"
        end

        schema(passthrough: true) do
          field :name, :string
        end
      end
    end

    it "keeps unknown fields in passthrough mode" do
      form = form_class.new(name: "John", extra: "value", another: 123)
      expect(form.valid?).to be true
      expect(form.attributes[:extra]).to eq("value")
      expect(form.attributes[:another]).to eq(123)
    end
  end

  describe "Multiple forms interaction" do
    let(:user_form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "UserForm"
        end

        schema do
          field :name, :string, min: 2
        end
      end
    end

    let(:profile_form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ProfileForm"
        end

        schema do
          field :bio, :string, max: 500
        end
      end
    end

    it "validates forms independently" do
      user = user_form_class.new(name: "Jo")
      profile = profile_form_class.new(bio: "A" * 600)

      expect(user.valid?).to be true
      expect(profile.valid?).to be false

      # Ensure no cross-contamination
      expect(user.errors).to be_empty
      expect(profile.errors[:bio]).not_to be_empty
    end
  end

  describe "Re-validation after attribute change" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "RevalidateForm"
        end

        schema do
          field :value, :integer, min: 0
        end

        # Allow updating raw_attributes for re-validation
        def update_attributes(attrs)
          @raw_attributes = attrs.transform_keys(&:to_sym)
          @validated = false
          @validation_result = nil
          attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
        end
      end
    end

    it "can be re-validated with new data" do
      form = form_class.new(value: -5)
      expect(form.valid?).to be false

      form.update_attributes(value: 10)
      expect(form.valid?).to be true
      expect(form.attributes[:value]).to eq(10)
    end
  end

  describe "Form with all constraint types" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "AllConstraintsForm"
        end

        schema do
          field :name, :string, min: 2, max: 50
          field :code, :string, length: 6
          field :email, :string, format: :email
          field :status, :string, enum: %w[active inactive]
          field :score, :integer, min: 0, max: 100
          field :tags, :array, of: :string, min: 1, max: 5
        end
      end
    end

    it "validates all constraints" do
      form = form_class.new(
        name: "John",
        code: "ABC123",
        email: "john@example.com",
        status: "active",
        score: 85,
        tags: %w[ruby rails]
      )
      expect(form.valid?).to be true
    end

    it "reports multiple constraint violations" do
      form = form_class.new(
        name: "J",
        code: "ABC",
        email: "invalid",
        status: "unknown",
        score: 150,
        tags: []
      )
      expect(form.valid?).to be false
      expect(form.errors.count).to be >= 5
    end
  end
end
