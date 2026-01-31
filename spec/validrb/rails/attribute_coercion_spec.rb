# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe Validrb::Rails::AttributeCoercion do
  # Create a minimal ActiveRecord-like class
  let(:base_model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      class << self
        attr_accessor :_attributes, :_before_validation_callbacks

        def attribute(name, _type = nil)
          @_attributes ||= []
          @_attributes << name
          attr_accessor name
        end

        def before_validation(method_name)
          @_before_validation_callbacks ||= []
          @_before_validation_callbacks << method_name
        end

        def name
          "TestModel"
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

      def valid?(context = nil)
        # Run before_validation callbacks
        self.class._before_validation_callbacks&.each do |callback|
          send(callback)
        end
        super
      end

      def write_attribute(name, value)
        instance_variable_set("@#{name}", value)
      end
    end
  end

  describe ".coerce_attributes_with" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :age
        attribute :active
        attribute :balance
        attribute :created_at

        coerce_attributes_with do
          field :age, :integer
          field :active, :boolean
          field :balance, :decimal
          field :created_at, :date
        end

        def self.name
          "CoercionModel"
        end
      end
    end

    it "coerces string to integer" do
      model = model_class.new(age: "25", active: true, balance: "100", created_at: "2024-01-15")
      model.valid?

      expect(model.age).to eq(25)
    end

    it "coerces string to boolean" do
      model = model_class.new(age: 25, active: "yes", balance: "100", created_at: "2024-01-15")
      model.valid?

      expect(model.active).to eq(true)
    end

    it "coerces string to decimal" do
      model = model_class.new(age: 25, active: true, balance: "99.99", created_at: "2024-01-15")
      model.valid?

      expect(model.balance).to be_a(BigDecimal)
      expect(model.balance).to eq(BigDecimal("99.99"))
    end

    it "coerces string to date" do
      model = model_class.new(age: 25, active: true, balance: "100", created_at: "2024-01-15")
      model.valid?

      expect(model.created_at).to eq(Date.new(2024, 1, 15))
    end

    it "handles already correct types" do
      model = model_class.new(age: 30, active: false, balance: BigDecimal("50"), created_at: Date.today)
      model.valid?

      expect(model.age).to eq(30)
      expect(model.active).to eq(false)
    end
  end

  describe "coercion on assignment" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :count

        coerce_attributes_with do
          field :count, :integer
        end

        def self.name
          "AssignmentModel"
        end
      end
    end

    it "coerces when attribute is assigned" do
      model = model_class.new
      model.count = "42"

      expect(model.count).to eq(42)
    end
  end

  describe ":only option" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :age
        attribute :score

        coerce_attributes_with only: [:age] do
          field :age, :integer
          field :score, :integer
        end

        def self.name
          "OnlyModel"
        end
      end
    end

    it "only coerces specified attributes" do
      model = model_class.new(age: "25", score: "100")
      model.valid?

      expect(model.age).to eq(25)
      expect(model.score).to eq("100")  # Not coerced
    end
  end

  describe ":except option" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :age
        attribute :legacy_field

        coerce_attributes_with except: [:legacy_field] do
          field :age, :integer
          field :legacy_field, :integer
        end

        def self.name
          "ExceptModel"
        end
      end
    end

    it "skips excluded attributes" do
      model = model_class.new(age: "25", legacy_field: "100")
      model.valid?

      expect(model.age).to eq(25)
      expect(model.legacy_field).to eq("100")  # Not coerced
    end
  end

  describe "with existing schema" do
    let(:shared_schema) do
      Validrb.schema do
        field :email, :string
        field :age, :integer
        field :verified, :boolean
      end
    end

    let(:model_class) do
      base = base_model_class
      schema = shared_schema
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :email
        attribute :age
        attribute :verified

        coerce_attributes_with schema

        def self.name
          "SharedSchemaModel"
        end
      end
    end

    it "uses the existing schema for coercion" do
      model = model_class.new(email: :test, age: "30", verified: "true")
      model.valid?

      expect(model.email).to eq("test")
      expect(model.age).to eq(30)
      expect(model.verified).to eq(true)
    end
  end

  describe "#coerce_single_attribute" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :value

        coerce_attributes_with do
          field :value, :integer
        end

        def self.name
          "SingleCoerceModel"
        end
      end
    end

    it "coerces a single attribute" do
      model = model_class.new
      result = model.coerce_single_attribute(:value, "42")

      expect(result).to eq(42)
    end

    it "returns original value if coercion fails" do
      model = model_class.new
      result = model.coerce_single_attribute(:value, "not a number")

      expect(result).to eq("not a number")
    end

    it "returns original value for unknown attribute" do
      model = model_class.new
      result = model.coerce_single_attribute(:unknown, "test")

      expect(result).to eq("test")
    end
  end

  describe "nested object coercion" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :settings

        coerce_attributes_with do
          field :settings, :object do
            field :theme, :string, default: "light"
            field :notifications, :boolean, default: true
          end
        end

        def self.name
          "NestedModel"
        end
      end
    end

    it "coerces nested objects" do
      model = model_class.new(settings: { theme: "dark", notifications: "false" })
      model.valid?

      expect(model.settings[:theme]).to eq("dark")
      expect(model.settings[:notifications]).to eq(false)
    end
  end

  describe "array coercion" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :scores

        coerce_attributes_with do
          field :scores, :array, of: :integer
        end

        def self.name
          "ArrayModel"
        end
      end
    end

    it "coerces array items" do
      model = model_class.new(scores: %w[85 90 95])
      model.valid?

      expect(model.scores).to eq([85, 90, 95])
    end
  end
end
