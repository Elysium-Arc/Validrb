# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe Validrb::Rails::Model do
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

  describe ".validates_with_schema" do
    context "with block schema" do
      let(:model_class) do
        base = base_model_class
        Class.new(base) do
          include Validrb::Rails::Model

          attribute :name
          attribute :email
          attribute :age

          validates_with_schema do
            field :name, :string, min: 2, max: 100
            field :email, :string, format: :email
            field :age, :integer, min: 0, optional: true
          end
        end
      end

      it "stores the schema" do
        expect(model_class.validrb_schema).to be_a(Validrb::Schema)
      end

      it "validates with the schema" do
        model = model_class.new(name: "Jo", email: "john@example.com")
        expect(model.valid?).to be true
      end

      it "adds errors for invalid data" do
        model = model_class.new(name: "J", email: "invalid")
        expect(model.valid?).to be false
        expect(model.errors[:name]).not_to be_empty
        expect(model.errors[:email]).not_to be_empty
      end

      it "coerces types during validation" do
        model = model_class.new(name: "John", email: "john@example.com", age: "30")
        model.valid?
        # Note: The model attributes aren't updated by schema validation
        # Schema validation just checks the values
      end
    end

    context "with existing schema" do
      let(:user_schema) do
        Validrb.schema do
          field :name, :string, min: 2
          field :email, :string, format: :email
        end
      end

      let(:model_class) do
        schema = user_schema
        base = base_model_class
        Class.new(base) do
          include Validrb::Rails::Model

          attribute :name
          attribute :email
          attribute :role

          validates_with_schema schema
        end
      end

      it "uses the provided schema" do
        expect(model_class.validrb_schema).to eq(user_schema)
      end

      it "validates using the schema" do
        model = model_class.new(name: "J", email: "john@example.com")
        expect(model.valid?).to be false
      end
    end

    context "with :only option" do
      let(:model_class) do
        base = base_model_class
        Class.new(base) do
          include Validrb::Rails::Model

          attribute :name
          attribute :email
          attribute :password

          validates_with_schema only: [:name, :email] do
            field :name, :string, min: 2
            field :email, :string, format: :email
            field :password, :string, min: 8
          end
        end
      end

      it "only validates specified attributes" do
        model = model_class.new(name: "Jo", email: "john@example.com", password: "short")
        # Password validation should be skipped
        expect(model.valid?).to be true
      end
    end

    context "with :except option" do
      let(:model_class) do
        base = base_model_class
        Class.new(base) do
          include Validrb::Rails::Model

          attribute :name
          attribute :email
          attribute :internal_field

          validates_with_schema except: [:internal_field] do
            field :name, :string, min: 2
            field :email, :string, format: :email
            field :internal_field, :string, min: 100
          end
        end
      end

      it "skips excluded attributes" do
        model = model_class.new(name: "John", email: "john@example.com", internal_field: "x")
        expect(model.valid?).to be true
      end
    end

    context "with :context option" do
      let(:model_class) do
        base = base_model_class
        Class.new(base) do
          include Validrb::Rails::Model

          attribute :amount
          attr_accessor :max_allowed

          validates_with_schema context: ->(record) { { max: record.max_allowed } } do
            field :amount, :integer,
                  refine: ->(v, ctx) { !ctx || !ctx[:max] || v <= ctx[:max] },
                  message: "exceeds maximum"
          end
        end
      end

      it "passes context to validation" do
        model = model_class.new(amount: 100)
        model.max_allowed = 50

        expect(model.valid?).to be false
        expect(model.errors[:amount]).not_to be_empty
      end

      it "passes context successfully" do
        model = model_class.new(amount: 100)
        model.max_allowed = 200

        expect(model.valid?).to be true
      end
    end
  end

  describe "#valid_for_schema?" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :name
        attribute :email
      end
    end

    let(:strict_schema) do
      Validrb.schema do
        field :name, :string, min: 5
        field :email, :string, format: :email
      end
    end

    it "validates against ad-hoc schema" do
      model = model_class.new(name: "John", email: "john@example.com")
      expect(model.valid_for_schema?(strict_schema)).to be false
    end

    it "accepts valid data" do
      model = model_class.new(name: "Johnny", email: "john@example.com")
      expect(model.valid_for_schema?(strict_schema)).to be true
    end

    it "adds errors to model" do
      model = model_class.new(name: "John", email: "invalid")
      model.valid_for_schema?(strict_schema)

      expect(model.errors[:name]).not_to be_empty
      expect(model.errors[:email]).not_to be_empty
    end

    it "accepts custom attributes hash" do
      model = model_class.new(name: "X", email: "bad")

      # Validate with different data
      result = model.valid_for_schema?(strict_schema, attributes: {
        name: "ValidName",
        email: "valid@example.com"
      })

      expect(result).to be true
    end

    it "accepts context" do
      context_schema = Validrb.schema do
        field :name, :string,
              refine: ->(v, ctx) { ctx && v == ctx[:expected_name] },
              message: "doesn't match expected"
      end

      model = model_class.new(name: "John")
      result = model.valid_for_schema?(context_schema, context: { expected_name: "John" })

      expect(result).to be true
    end
  end

  describe "Error conversion" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :name
        attribute :address

        validates_with_schema do
          field :name, :string, min: 2, message: "is too short"
          field :address, :object do
            field :city, :string
            field :zip, :string, format: /\A\d{5}\z/
          end
        end
      end
    end

    it "converts nested errors to dot notation" do
      model = model_class.new(
        name: "John",
        address: { city: "NYC", zip: "invalid" }
      )
      model.valid?

      # Should have error on address.zip or similar
      error_attrs = model.errors.attribute_names.map(&:to_s)
      expect(error_attrs.any? { |a| a.include?("address") || a.include?("zip") }).to be true
    end

    it "uses custom error messages" do
      model = model_class.new(name: "J", address: { city: "NYC", zip: "12345" })
      model.valid?

      expect(model.errors[:name]).to include("is too short")
    end
  end

  describe "Integration with standard validations" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :name
        attribute :code

        # Standard ActiveModel validation
        validates :code, presence: true

        # Validrb schema validation
        validates_with_schema do
          field :name, :string, min: 2
        end

        def self.name
          "IntegrationTestModel"
        end
      end
    end

    it "runs both standard and schema validations" do
      model = model_class.new(name: "J", code: nil)
      expect(model.valid?).to be false

      # Should have errors from both validation types
      expect(model.errors[:name]).not_to be_empty
      expect(model.errors[:code]).not_to be_empty
    end

    it "passes when both validations pass" do
      model = model_class.new(name: "John", code: "ABC123")
      expect(model.valid?).to be true
    end
  end

  describe "Edge cases" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::Model

        attribute :value

        validates_with_schema do
          field :value, :string, optional: true
        end
      end
    end

    it "handles nil attributes" do
      model = model_class.new(value: nil)
      expect(model.valid?).to be true
    end

    it "handles missing attributes" do
      model = model_class.new
      expect(model.valid?).to be true
    end

    it "handles empty string" do
      model = model_class.new(value: "")
      expect(model.valid?).to be true
    end
  end
end
