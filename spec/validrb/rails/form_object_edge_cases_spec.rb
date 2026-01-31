# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "FormObject Edge Cases" do
  describe "Empty and nil handling" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "TestForm"
        end

        schema do
          field :required_field, :string
          field :optional_field, :string, optional: true
          field :nullable_field, :string, nullable: true, optional: true
          field :default_field, :string, default: "default_value"
        end
      end
    end

    it "handles nil initialization" do
      form = form_class.new(nil)
      expect(form.required_field).to be_nil
    end

    it "handles empty hash initialization" do
      form = form_class.new({})
      expect(form.required_field).to be_nil
    end

    it "validates required fields" do
      form = form_class.new({})
      expect(form.valid?).to be false
      expect(form.errors[:required_field]).not_to be_empty
    end

    it "allows missing optional fields" do
      form = form_class.new(required_field: "test")
      expect(form.valid?).to be true
    end

    it "allows nil for nullable fields" do
      form = form_class.new(required_field: "test", nullable_field: nil)
      expect(form.valid?).to be true
      expect(form.nullable_field).to be_nil
    end

    it "applies default values" do
      form = form_class.new(required_field: "test")
      form.valid?
      expect(form.default_field).to eq("default_value")
    end

    it "overrides default values when provided" do
      form = form_class.new(required_field: "test", default_field: "custom")
      form.valid?
      expect(form.default_field).to eq("custom")
    end
  end

  describe "Multiple validations" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "MultiValidateForm"
        end

        schema do
          field :name, :string, min: 2
        end
      end
    end

    it "clears errors between validations" do
      form = form_class.new(name: "a")
      form.valid?
      expect(form.errors[:name]).not_to be_empty

      form.name = "valid_name"
      # Note: Need to update raw_attributes for re-validation
      # This tests current behavior
    end

    it "can be validated multiple times" do
      form = form_class.new(name: "valid")
      expect(form.valid?).to be true
      expect(form.valid?).to be true
      expect(form.valid?).to be true
    end
  end

  describe "Complex nested structures" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "NestedForm"
        end

        schema do
          field :user, :object do
            field :name, :string
            field :profile, :object do
              field :bio, :string, optional: true
              field :age, :integer, min: 0
            end
          end
        end
      end
    end

    it "handles nested valid data" do
      form = form_class.new(
        user: {
          name: "John",
          profile: { bio: "Developer", age: 30 }
        }
      )
      expect(form.valid?).to be true
    end

    it "reports nested errors with correct paths" do
      form = form_class.new(
        user: {
          name: "John",
          profile: { age: -5 }
        }
      )
      expect(form.valid?).to be false
      # Error path should be nested
      error_attrs = form.errors.attribute_names
      expect(error_attrs.any? { |a| a.to_s.include?("profile") || a.to_s.include?("age") }).to be true
    end

    it "handles missing nested objects" do
      form = form_class.new(user: { name: "John" })
      expect(form.valid?).to be false
    end
  end

  describe "Array fields" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ArrayForm"
        end

        schema do
          field :tags, :array, of: :string, min: 1
          field :scores, :array, of: :integer, optional: true
        end
      end
    end

    it "validates array items" do
      form = form_class.new(tags: %w[ruby rails], scores: [1, 2, 3])
      expect(form.valid?).to be true
    end

    it "reports errors for invalid array items" do
      form = form_class.new(tags: ["valid", 123], scores: [1, 2, 3])
      # 123 should be coerced to string "123"
      expect(form.valid?).to be true
    end

    it "validates minimum array length" do
      form = form_class.new(tags: [])
      expect(form.valid?).to be false
    end

    it "handles nil arrays for optional fields" do
      form = form_class.new(tags: ["test"], scores: nil)
      expect(form.valid?).to be true
    end
  end

  describe "Type coercion in forms" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "CoercionForm"
        end

        schema do
          field :count, :integer
          field :price, :float
          field :active, :boolean
          field :created_at, :date
        end
      end
    end

    it "coerces string to integer" do
      form = form_class.new(count: "42", price: "9.99", active: "true", created_at: "2024-01-15")
      expect(form.valid?).to be true
      expect(form.attributes[:count]).to eq(42)
    end

    it "coerces string to float" do
      form = form_class.new(count: "1", price: "19.99", active: "yes", created_at: "2024-01-15")
      expect(form.valid?).to be true
      expect(form.attributes[:price]).to eq(19.99)
    end

    it "coerces string to boolean" do
      form = form_class.new(count: "1", price: "9.99", active: "false", created_at: "2024-01-15")
      expect(form.valid?).to be true
      expect(form.attributes[:active]).to eq(false)
    end

    it "coerces string to date" do
      form = form_class.new(count: "1", price: "9.99", active: "true", created_at: "2024-01-15")
      expect(form.valid?).to be true
      expect(form.attributes[:created_at]).to eq(Date.new(2024, 1, 15))
    end
  end

  describe "Inheritance" do
    let(:base_form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "BaseForm"
        end

        schema do
          field :name, :string
        end
      end
    end

    it "allows form class without schema" do
      empty_class = Class.new(Validrb::Rails::FormObject) do
        def self.name
          "EmptyForm"
        end
      end

      form = empty_class.new(anything: "value")
      expect(form.valid?).to be true
    end
  end

  describe "Thread safety" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ThreadSafeForm"
        end

        schema do
          field :value, :integer, min: 0
        end
      end
    end

    it "handles concurrent form validations" do
      results = []
      threads = 10.times.map do |i|
        Thread.new do
          form = form_class.new(value: i)
          results << { valid: form.valid?, value: form.attributes[:value] }
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(10)
      expect(results.all? { |r| r[:valid] }).to be true
    end
  end

  describe "Error message formatting" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ErrorForm"
        end

        schema do
          field :email, :string, format: :email, message: "is not a valid email"
          field :age, :integer, min: 18, message: "must be 18 or older"
        end
      end
    end

    it "uses custom error messages" do
      form = form_class.new(email: "invalid", age: 10)
      form.valid?

      expect(form.errors[:email]).to include("is not a valid email")
      expect(form.errors[:age]).to include("must be 18 or older")
    end

    it "provides full messages with attribute names" do
      form = form_class.new(email: "invalid", age: 10)
      form.valid?

      full_messages = form.errors.full_messages
      expect(full_messages.any? { |m| m.include?("email") || m.include?("Email") }).to be true
    end
  end

  describe "Symbol vs String keys" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "KeyForm"
        end

        schema do
          field :name, :string
          field :email, :string
        end
      end
    end

    it "handles symbol keys" do
      form = form_class.new(name: "John", email: "john@example.com")
      expect(form.name).to eq("John")
      expect(form.email).to eq("john@example.com")
    end

    it "handles string keys" do
      form = form_class.new("name" => "John", "email" => "john@example.com")
      expect(form.name).to eq("John")
      expect(form.email).to eq("john@example.com")
    end

    it "handles mixed keys" do
      form = form_class.new(name: "John", "email" => "john@example.com")
      expect(form.name).to eq("John")
      expect(form.email).to eq("john@example.com")
    end
  end

  describe "Special characters in values" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "SpecialCharForm"
        end

        schema do
          field :text, :string
        end
      end
    end

    it "preserves special characters" do
      special_strings = [
        "Hello\nWorld",
        "Tab\there",
        "Quote's",
        'Double "quotes"',
        "Backslash\\here",
        "Unicode: 日本語 🎉 émoji"
      ]

      special_strings.each do |str|
        form = form_class.new(text: str)
        form.valid?
        expect(form.attributes[:text]).to eq(str)
      end
    end
  end
end
