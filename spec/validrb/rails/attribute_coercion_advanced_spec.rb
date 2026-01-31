# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "AttributeCoercion Advanced Features" do
  # Enhanced ActiveRecord-like base class
  let(:base_model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      class << self
        attr_accessor :_attributes, :_before_validation_callbacks

        def attribute(name, _type = nil, **options)
          @_attributes ||= []
          @_attributes << name
          attr_accessor name

          # Handle default values
          if options[:default]
            default_val = options[:default]
            define_method(name) do
              val = instance_variable_get("@#{name}")
              val.nil? ? default_val : val
            end
          end
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

  describe "All type coercions" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :string_field
        attribute :integer_field
        attribute :float_field
        attribute :boolean_field
        attribute :decimal_field
        attribute :date_field
        attribute :datetime_field
        attribute :time_field

        coerce_attributes_with do
          field :string_field, :string
          field :integer_field, :integer
          field :float_field, :float
          field :boolean_field, :boolean
          field :decimal_field, :decimal
          field :date_field, :date
          field :datetime_field, :datetime
          field :time_field, :time
        end

        def self.name
          "AllTypesModel"
        end
      end
    end

    it "coerces symbol to string" do
      model = model_class.new(
        string_field: :symbol_value,
        integer_field: 1, float_field: 1.0, boolean_field: true,
        decimal_field: "1", date_field: "2024-01-15",
        datetime_field: "2024-01-15T10:00:00", time_field: "10:00:00"
      )
      model.valid?
      expect(model.string_field).to eq("symbol_value")
    end

    it "coerces string to integer" do
      model = model_class.new(
        string_field: "test", integer_field: "42",
        float_field: 1.0, boolean_field: true,
        decimal_field: "1", date_field: "2024-01-15",
        datetime_field: "2024-01-15T10:00:00", time_field: "10:00:00"
      )
      model.valid?
      expect(model.integer_field).to eq(42)
    end

    it "coerces string to float" do
      model = model_class.new(
        string_field: "test", integer_field: 1,
        float_field: "3.14", boolean_field: true,
        decimal_field: "1", date_field: "2024-01-15",
        datetime_field: "2024-01-15T10:00:00", time_field: "10:00:00"
      )
      model.valid?
      expect(model.float_field).to eq(3.14)
    end

    it "coerces various boolean representations" do
      [
        ["true", true], ["false", false],
        ["yes", true], ["no", false],
        ["1", true], ["0", false],
        ["on", true], ["off", false]
      ].each do |input, expected|
        model = model_class.new(
          string_field: "test", integer_field: 1,
          float_field: 1.0, boolean_field: input,
          decimal_field: "1", date_field: "2024-01-15",
          datetime_field: "2024-01-15T10:00:00", time_field: "10:00:00"
        )
        model.valid?
        expect(model.boolean_field).to eq(expected), "Expected '#{input}' to coerce to #{expected}"
      end
    end

    it "coerces string to decimal" do
      model = model_class.new(
        string_field: "test", integer_field: 1,
        float_field: 1.0, boolean_field: true,
        decimal_field: "123.456", date_field: "2024-01-15",
        datetime_field: "2024-01-15T10:00:00", time_field: "10:00:00"
      )
      model.valid?
      expect(model.decimal_field).to be_a(BigDecimal)
      expect(model.decimal_field).to eq(BigDecimal("123.456"))
    end

    it "coerces string to date" do
      model = model_class.new(
        string_field: "test", integer_field: 1,
        float_field: 1.0, boolean_field: true,
        decimal_field: "1", date_field: "2024-06-15",
        datetime_field: "2024-01-15T10:00:00", time_field: "10:00:00"
      )
      model.valid?
      expect(model.date_field).to eq(Date.new(2024, 6, 15))
    end

    it "coerces string to datetime" do
      model = model_class.new(
        string_field: "test", integer_field: 1,
        float_field: 1.0, boolean_field: true,
        decimal_field: "1", date_field: "2024-01-15",
        datetime_field: "2024-06-15T14:30:00", time_field: "10:00:00"
      )
      model.valid?
      expect(model.datetime_field).to be_a(DateTime)
    end
  end

  describe "Coercion on attribute assignment" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :count
        attribute :active
        attribute :price

        coerce_attributes_with do
          field :count, :integer
          field :active, :boolean
          field :price, :decimal
        end

        def self.name
          "AssignmentModel"
        end
      end
    end

    it "coerces immediately on assignment" do
      model = model_class.new
      model.count = "100"
      model.active = "yes"
      model.price = "49.99"

      # Values are coerced immediately, no need to call valid?
      expect(model.count).to eq(100)
      expect(model.active).to eq(true)
      expect(model.price).to eq(BigDecimal("49.99"))
    end

    it "handles nil assignment" do
      model = model_class.new(count: 10, active: true, price: "10")
      model.count = nil

      expect(model.count).to be_nil
    end
  end

  describe "Nested object coercion" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :config

        coerce_attributes_with do
          field :config, :object do
            field :enabled, :boolean, default: false
            field :max_retries, :integer, default: 3
            field :timeout, :float, default: 30.0
          end
        end

        def self.name
          "NestedModel"
        end
      end
    end

    it "coerces nested object values" do
      model = model_class.new(config: {
        enabled: "true",
        max_retries: "5",
        timeout: "60.5"
      })
      model.valid?

      expect(model.config[:enabled]).to eq(true)
      expect(model.config[:max_retries]).to eq(5)
      expect(model.config[:timeout]).to eq(60.5)
    end

    it "applies nested defaults" do
      model = model_class.new(config: { enabled: "true" })
      model.valid?

      expect(model.config[:max_retries]).to eq(3)
      expect(model.config[:timeout]).to eq(30.0)
    end
  end

  describe "Array coercion" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :tags
        attribute :scores
        attribute :prices

        coerce_attributes_with do
          field :tags, :array, of: :string
          field :scores, :array, of: :integer
          field :prices, :array, of: :decimal
        end

        def self.name
          "ArrayModel"
        end
      end
    end

    it "coerces array of strings" do
      model = model_class.new(
        tags: [:ruby, :rails, :web],
        scores: [1, 2, 3],
        prices: ["1"]
      )
      model.valid?

      expect(model.tags).to eq(%w[ruby rails web])
    end

    it "coerces array of integers" do
      model = model_class.new(
        tags: ["a"],
        scores: %w[85 90 95],
        prices: ["1"]
      )
      model.valid?

      expect(model.scores).to eq([85, 90, 95])
    end

    it "coerces array of decimals" do
      model = model_class.new(
        tags: ["a"],
        scores: [1],
        prices: %w[19.99 29.99 39.99]
      )
      model.valid?

      expect(model.prices).to all(be_a(BigDecimal))
      expect(model.prices.first).to eq(BigDecimal("19.99"))
    end
  end

  describe "Failed coercion handling" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :count

        coerce_attributes_with do
          field :count, :integer
        end

        def self.name
          "FailedCoercionModel"
        end
      end
    end

    it "keeps original value when coercion fails" do
      model = model_class.new
      result = model.coerce_single_attribute(:count, "not_a_number")

      expect(result).to eq("not_a_number")
    end

    it "handles coercion errors gracefully" do
      model = model_class.new(count: "invalid")

      # Should not raise
      expect { model.valid? }.not_to raise_error
    end
  end

  describe "Combined with Model validation" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion
        include Validrb::Rails::Model

        attribute :age
        attribute :email

        coerce_attributes_with do
          field :age, :integer
          field :email, :string
        end

        validates_with_schema do
          field :age, :integer, min: 0, max: 150
          field :email, :string, format: :email
        end

        def self.name
          "CombinedModel"
        end
      end
    end

    it "coerces then validates" do
      model = model_class.new(age: "25", email: "test@example.com")

      expect(model.valid?).to be true
      expect(model.age).to eq(25)
    end

    it "validates coerced values" do
      model = model_class.new(age: "-5", email: "test@example.com")

      expect(model.valid?).to be false
      expect(model.errors[:age]).not_to be_empty
    end
  end

  describe "Preprocessing in coercion" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :email
        attribute :phone

        coerce_attributes_with do
          field :email, :string, preprocess: ->(v) { v&.strip&.downcase }
          field :phone, :string, preprocess: ->(v) { v&.gsub(/\D/, "") }
        end

        def self.name
          "PreprocessModel"
        end
      end
    end

    it "applies preprocessing during coercion" do
      model = model_class.new(
        email: "  JOHN@EXAMPLE.COM  ",
        phone: "+1 (555) 123-4567"
      )
      model.valid?

      expect(model.email).to eq("john@example.com")
      expect(model.phone).to eq("15551234567")
    end
  end

  describe "Thread safety" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :value

        coerce_attributes_with do
          field :value, :integer
        end

        def self.name
          "ThreadSafeModel"
        end
      end
    end

    it "handles concurrent coercions" do
      results = []
      mutex = Mutex.new

      threads = 20.times.map do |i|
        Thread.new do
          model = model_class.new(value: i.to_s)
          model.valid?
          mutex.synchronize { results << model.value }
        end
      end

      threads.each(&:join)

      expect(results.sort).to eq((0..19).to_a)
    end
  end

  describe "Schema reuse" do
    let(:shared_schema) do
      Validrb.schema do
        field :name, :string
        field :count, :integer
        field :active, :boolean
      end
    end

    let(:model_a_class) do
      base = base_model_class
      schema = shared_schema
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :name
        attribute :count
        attribute :active

        coerce_attributes_with schema

        def self.name
          "ModelA"
        end
      end
    end

    let(:model_b_class) do
      base = base_model_class
      schema = shared_schema
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :name
        attribute :count
        attribute :active

        coerce_attributes_with schema

        def self.name
          "ModelB"
        end
      end
    end

    it "shares schema between models" do
      model_a = model_a_class.new(name: :test, count: "10", active: "yes")
      model_b = model_b_class.new(name: :other, count: "20", active: "no")

      model_a.valid?
      model_b.valid?

      expect(model_a.count).to eq(10)
      expect(model_b.count).to eq(20)
      expect(model_a.active).to eq(true)
      expect(model_b.active).to eq(false)
    end
  end

  describe "Edge cases" do
    let(:model_class) do
      base = base_model_class
      Class.new(base) do
        include Validrb::Rails::AttributeCoercion

        attribute :value

        coerce_attributes_with do
          field :value, :integer
        end

        def self.name
          "EdgeCaseModel"
        end
      end
    end

    it "handles empty string" do
      model = model_class.new(value: "")
      # Empty string cannot be coerced to integer
      expect(model.value).to eq("")
    end

    it "handles whitespace string" do
      model = model_class.new(value: "   ")
      expect(model.value).to eq("   ")
    end

    it "handles very large numbers" do
      model = model_class.new(value: "999999999999999999999")
      expect(model.value).to eq(999999999999999999999)
    end

    it "handles negative numbers" do
      model = model_class.new(value: "-42")
      expect(model.value).to eq(-42)
    end

    it "handles float strings for integer field" do
      model = model_class.new(value: "42.0")
      # "42.0" should coerce to 42 (whole number)
      expect(model.value).to eq(42)
    end
  end
end
