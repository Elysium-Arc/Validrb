# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "Model Advanced Features" do
  # Create a minimal ActiveRecord-like base class for testing
  let(:base_model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      class << self
        attr_accessor :_attributes

        def attribute(name, _type = nil)
          @_attributes ||= []
          @_attributes << name
          attr_accessor name
        end

        def name
          "BaseTestModel"
        end
      end

      def initialize(attrs = {})
        attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
      end

      def attributes
        self.class._attributes&.each_with_object({}) do |attr, hash|
          hash[attr.to_s] = send(attr)
        end || {}
      end
    end
  end

  describe "Schema with computed validations" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :start_date
        attribute :end_date
        attribute :duration_days

        validates_with_schema do
          field :start_date, :date
          field :end_date, :date
          field :duration_days, :integer, optional: true

          validate do |data|
            if data[:start_date] && data[:end_date]
              if data[:start_date] > data[:end_date]
                error(:end_date, "must be after start date")
              end

              if data[:duration_days]
                expected = (data[:end_date] - data[:start_date]).to_i
                if data[:duration_days] != expected
                  error(:duration_days, "does not match date range")
                end
              end
            end
          end
        end

        def self.name
          "DateRangeModel"
        end
      end
    end

    it "validates date range" do
      model = model_class.new(
        start_date: "2024-01-01",
        end_date: "2024-01-10",
        duration_days: 9
      )
      expect(model.valid?).to be true
    end

    it "rejects invalid date range" do
      model = model_class.new(
        start_date: "2024-01-10",
        end_date: "2024-01-01"
      )
      expect(model.valid?).to be false
      expect(model.errors[:end_date]).not_to be_empty
    end

    it "validates duration matches" do
      model = model_class.new(
        start_date: "2024-01-01",
        end_date: "2024-01-10",
        duration_days: 5  # Wrong
      )
      expect(model.valid?).to be false
      expect(model.errors[:duration_days]).not_to be_empty
    end
  end

  describe "Schema with context-dependent validation" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :amount
        attribute :currency
        attr_accessor :exchange_rates

        validates_with_schema context: ->(record) { { rates: record.exchange_rates } } do
          field :amount, :decimal, min: 0
          field :currency, :string, enum: %w[USD EUR GBP JPY]

          validate do |data, ctx|
            next unless ctx && ctx[:rates]

            currency = data[:currency]
            unless ctx[:rates].key?(currency)
              error(:currency, "exchange rate not available")
            end
          end
        end

        def self.name
          "CurrencyModel"
        end
      end
    end

    it "validates with context" do
      model = model_class.new(amount: "100", currency: "USD")
      model.exchange_rates = { "USD" => 1.0, "EUR" => 0.85 }

      expect(model.valid?).to be true
    end

    it "fails when currency not in rates" do
      model = model_class.new(amount: "100", currency: "GBP")
      model.exchange_rates = { "USD" => 1.0, "EUR" => 0.85 }

      expect(model.valid?).to be false
      expect(model.errors[:currency]).not_to be_empty
    end
  end

  describe "Schema with :on option" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :email
        attribute :password
        attribute :name

        # Only validate on create
        validates_with_schema on: :create do
          field :email, :string, format: :email
          field :password, :string, min: 8
          field :name, :string, min: 2
        end

        def self.name
          "UserModel"
        end
      end
    end

    it "validates on create context" do
      model = model_class.new(email: "test@example.com", password: "short", name: "Jo")
      expect(model.valid?(:create)).to be false
      expect(model.errors[:password]).not_to be_empty
    end

    it "skips validation on other contexts" do
      model = model_class.new(email: "invalid", password: "x", name: "")
      # Without :create context, the schema validation is skipped
      expect(model.valid?(:update)).to be true
    end

    it "skips validation without context" do
      model = model_class.new(email: "invalid", password: "x")
      # valid? without context doesn't match :create
      expect(model.valid?).to be true
    end
  end

  describe "Nested object validation" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :name
        attribute :settings

        validates_with_schema do
          field :name, :string
          field :settings, :object do
            field :notifications, :object do
              field :email, :boolean, default: true
              field :sms, :boolean, default: false
              field :push, :boolean, default: true
            end
            field :privacy, :object do
              field :public_profile, :boolean, default: false
              field :show_email, :boolean, default: false
            end
          end
        end

        def self.name
          "SettingsModel"
        end
      end
    end

    it "validates nested settings" do
      model = model_class.new(
        name: "John",
        settings: {
          notifications: { email: true, sms: false, push: true },
          privacy: { public_profile: true, show_email: false }
        }
      )
      expect(model.valid?).to be true
    end

    it "reports deeply nested errors" do
      model = model_class.new(
        name: "John",
        settings: {
          notifications: { email: "not-boolean" },
          privacy: { public_profile: true }
        }
      )
      expect(model.valid?).to be false
    end
  end

  describe "Array attribute validation" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :tags
        attribute :scores
        attribute :contacts

        validates_with_schema do
          field :tags, :array, of: :string, min: 1, max: 10
          field :scores, :array, of: :integer, optional: true
          field :contacts, :array, optional: true do
            field :name, :string
            field :email, :string, format: :email
          end
        end

        def self.name
          "ArrayModel"
        end
      end
    end

    it "validates arrays" do
      model = model_class.new(
        tags: %w[ruby rails web],
        scores: [85, 90, 95],
        contacts: [
          { name: "John", email: "john@example.com" },
          { name: "Jane", email: "jane@example.com" }
        ]
      )
      expect(model.valid?).to be true
    end

    it "validates array constraints" do
      model = model_class.new(tags: [])
      expect(model.valid?).to be false
      expect(model.errors[:tags]).not_to be_empty
    end

    it "validates array item objects" do
      model = model_class.new(
        tags: ["test"],
        contacts: [{ name: "John", email: "invalid" }]
      )
      expect(model.valid?).to be false
    end
  end

  describe "Transforms in model validation" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :email
        attribute :phone

        validates_with_schema do
          field :email, :string,
                preprocess: ->(v) { v&.strip&.downcase },
                format: :email
          field :phone, :string,
                preprocess: ->(v) { v&.gsub(/\D/, "") },
                format: /\A\d{10,15}\z/
        end

        def self.name
          "TransformModel"
        end
      end
    end

    it "applies preprocessing" do
      model = model_class.new(
        email: "  JOHN@EXAMPLE.COM  ",
        phone: "+1 (555) 123-4567"
      )
      expect(model.valid?).to be true
    end

    it "validates after preprocessing" do
      model = model_class.new(
        email: "  not an email  ",
        phone: "abc"
      )
      expect(model.valid?).to be false
    end
  end

  describe "Conditional validation" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :account_type
        attribute :company_name
        attribute :tax_id
        attribute :personal_id

        validates_with_schema do
          field :account_type, :string, enum: %w[personal business]
          field :company_name, :string, min: 2, when: ->(data) { data[:account_type] == "business" }
          field :tax_id, :string, format: /\A\d{9}\z/, when: ->(data) { data[:account_type] == "business" }
          field :personal_id, :string, min: 5, unless: ->(data) { data[:account_type] == "business" }
        end

        def self.name
          "ConditionalModel"
        end
      end
    end

    it "validates business account" do
      model = model_class.new(
        account_type: "business",
        company_name: "Acme Inc",
        tax_id: "123456789"
      )
      expect(model.valid?).to be true
    end

    it "validates personal account" do
      model = model_class.new(
        account_type: "personal",
        personal_id: "12345"
      )
      expect(model.valid?).to be true
    end

    it "fails when business missing required fields" do
      model = model_class.new(
        account_type: "business"
      )
      expect(model.valid?).to be false
      expect(model.errors[:company_name]).not_to be_empty
      expect(model.errors[:tax_id]).not_to be_empty
    end
  end

  describe "Combined ActiveModel and Validrb validations" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :username
        attribute :email
        attribute :age
        attribute :terms_accepted

        # Standard ActiveModel validations
        validates :username, presence: true, length: { minimum: 3, maximum: 20 }
        validates :terms_accepted, acceptance: true

        # Validrb schema validation
        validates_with_schema do
          field :email, :string, format: :email
          field :age, :integer, min: 13, optional: true
        end

        def self.name
          "CombinedModel"
        end
      end
    end

    it "runs both validation types" do
      model = model_class.new(
        username: "ab",  # Too short (ActiveModel)
        email: "invalid",  # Invalid (Validrb)
        terms_accepted: false  # Not accepted (ActiveModel)
      )
      expect(model.valid?).to be false
      expect(model.errors[:username]).not_to be_empty
      expect(model.errors[:email]).not_to be_empty
      expect(model.errors[:terms_accepted]).not_to be_empty
    end

    it "passes when all validations pass" do
      model = model_class.new(
        username: "johndoe",
        email: "john@example.com",
        age: 25,
        terms_accepted: "1"
      )
      expect(model.valid?).to be true
    end
  end

  describe "Schema reuse across models" do
    let(:address_schema) do
      Validrb.schema do
        field :street, :string, min: 1
        field :city, :string, min: 1
        field :zip, :string, format: /\A\d{5}\z/
        field :country, :string, default: "US"
      end
    end

    let(:user_model_class) do
      base = base_model_class
      schema = address_schema
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :name
        attribute :address

        validates_with_schema do
          field :name, :string, min: 2
          field :address, :object, schema: schema
        end

        def self.name
          "UserWithAddress"
        end
      end
    end

    let(:company_model_class) do
      base = base_model_class
      schema = address_schema
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :company_name
        attribute :headquarters

        validates_with_schema do
          field :company_name, :string, min: 2
          field :headquarters, :object, schema: schema
        end

        def self.name
          "CompanyWithAddress"
        end
      end
    end

    it "validates user with shared schema" do
      user = user_model_class.new(
        name: "John",
        address: { street: "123 Main", city: "NYC", zip: "12345" }
      )
      expect(user.valid?).to be true
    end

    it "validates company with shared schema" do
      company = company_model_class.new(
        company_name: "Acme Inc",
        headquarters: { street: "456 Corp Blvd", city: "SF", zip: "94102" }
      )
      expect(company.valid?).to be true
    end

    it "applies same validation rules to both" do
      user = user_model_class.new(
        name: "John",
        address: { street: "", city: "NYC", zip: "invalid" }
      )
      company = company_model_class.new(
        company_name: "Acme",
        headquarters: { street: "", city: "SF", zip: "invalid" }
      )

      expect(user.valid?).to be false
      expect(company.valid?).to be false
    end
  end

  describe "Error handling edge cases" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :data

        validates_with_schema do
          field :data, :object do
            field :level1, :object do
              field :level2, :object do
                field :value, :integer, min: 0
              end
            end
          end
        end

        def self.name
          "DeeplyNestedModel"
        end
      end
    end

    it "handles deeply nested errors" do
      model = model_class.new(
        data: {
          level1: {
            level2: {
              value: -5
            }
          }
        }
      )
      expect(model.valid?).to be false
      error_attrs = model.errors.attribute_names.map(&:to_s)
      expect(error_attrs.any? { |a| a.include?("level2") || a.include?("value") }).to be true
    end

    it "handles missing nested objects" do
      model = model_class.new(data: { level1: {} })
      expect(model.valid?).to be false
    end
  end

  describe "Decimal precision handling" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :price
        attribute :tax_rate
        attribute :total

        validates_with_schema do
          field :price, :decimal, min: 0
          field :tax_rate, :decimal, min: 0, max: 1
          field :total, :decimal, min: 0, optional: true

          validate do |data|
            if data[:price] && data[:tax_rate] && data[:total]
              expected = data[:price] * (1 + data[:tax_rate])
              # Allow small floating point differences
              if (data[:total] - expected).abs > BigDecimal("0.01")
                error(:total, "does not match calculated total")
              end
            end
          end
        end

        def self.name
          "DecimalModel"
        end
      end
    end

    it "validates decimal calculations" do
      model = model_class.new(
        price: "100.00",
        tax_rate: "0.08",
        total: "108.00"
      )
      expect(model.valid?).to be true
    end

    it "detects incorrect totals" do
      model = model_class.new(
        price: "100.00",
        tax_rate: "0.08",
        total: "110.00"  # Wrong
      )
      expect(model.valid?).to be false
      expect(model.errors[:total]).not_to be_empty
    end
  end
end
