# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe Validrb::Rails::FormObject do
  let(:user_form_class) do
    Class.new(described_class) do
      # Give it a name for model_name
      def self.name
        "UserForm"
      end

      schema do
        field :name, :string, min: 2, max: 100
        field :email, :string, format: :email
        field :age, :integer, optional: true
        field :admin, :boolean, default: false
      end
    end
  end

  describe ".schema" do
    it "creates a validrb schema" do
      expect(user_form_class.validrb_schema).to be_a(Validrb::Schema)
    end

    it "defines attribute accessors" do
      form = user_form_class.new
      expect(form).to respond_to(:name)
      expect(form).to respond_to(:name=)
      expect(form).to respond_to(:email)
      expect(form).to respond_to(:age)
    end
  end

  describe ".use_schema" do
    let(:existing_schema) do
      Validrb.schema do
        field :title, :string
      end
    end

    let(:form_class) do
      schema = existing_schema
      Class.new(described_class) do
        def self.name
          "ArticleForm"
        end

        use_schema schema
      end
    end

    it "uses the provided schema" do
      expect(form_class.validrb_schema).to eq(existing_schema)
    end

    it "defines attribute accessors" do
      form = form_class.new
      expect(form).to respond_to(:title)
    end
  end

  describe ".model_name" do
    it "returns ActiveModel::Name" do
      expect(user_form_class.model_name).to be_a(ActiveModel::Name)
    end

    it "derives name from class name" do
      expect(user_form_class.model_name.singular).to eq("user")
      expect(user_form_class.model_name.human).to eq("User")
    end
  end

  describe "#initialize" do
    it "accepts hash attributes" do
      form = user_form_class.new(name: "John", email: "john@example.com")

      expect(form.name).to eq("John")
      expect(form.email).to eq("john@example.com")
    end

    it "accepts string keys" do
      form = user_form_class.new("name" => "John", "email" => "john@example.com")

      expect(form.name).to eq("John")
      expect(form.email).to eq("john@example.com")
    end

    it "handles missing attributes" do
      form = user_form_class.new(name: "John")

      expect(form.name).to eq("John")
      expect(form.email).to be_nil
    end
  end

  describe "#valid?" do
    context "with valid data" do
      it "returns true" do
        form = user_form_class.new(name: "John Doe", email: "john@example.com")
        expect(form.valid?).to be true
      end

      it "updates attributes with coerced values" do
        form = user_form_class.new(name: "John", email: "john@example.com", age: "30")
        form.valid?

        expect(form.age).to eq(30)
      end

      it "applies defaults" do
        form = user_form_class.new(name: "John", email: "john@example.com")
        form.valid?

        expect(form.admin).to eq(false)
      end
    end

    context "with invalid data" do
      it "returns false" do
        form = user_form_class.new(name: "J", email: "invalid")
        expect(form.valid?).to be false
      end

      it "populates errors" do
        form = user_form_class.new(name: "J", email: "invalid")
        form.valid?

        expect(form.errors[:name]).not_to be_empty
        expect(form.errors[:email]).not_to be_empty
      end

      it "includes error messages" do
        form = user_form_class.new(name: "", email: "john@example.com")
        form.valid?

        expect(form.errors.full_messages).not_to be_empty
      end
    end
  end

  describe "#validated?" do
    it "returns false before validation" do
      form = user_form_class.new(name: "John", email: "john@example.com")
      expect(form.validated?).to be false
    end

    it "returns true after validation" do
      form = user_form_class.new(name: "John", email: "john@example.com")
      form.valid?
      expect(form.validated?).to be true
    end
  end

  describe "#validation_result" do
    it "returns nil before validation" do
      form = user_form_class.new(name: "John", email: "john@example.com")
      expect(form.validation_result).to be_nil
    end

    it "returns Success after valid validation" do
      form = user_form_class.new(name: "John", email: "john@example.com")
      form.valid?
      expect(form.validation_result).to be_a(Validrb::Success)
    end

    it "returns Failure after invalid validation" do
      form = user_form_class.new(name: "", email: "invalid")
      form.valid?
      expect(form.validation_result).to be_a(Validrb::Failure)
    end
  end

  describe "#attributes" do
    it "returns raw attributes before validation" do
      form = user_form_class.new(name: "John", email: "john@example.com")
      expect(form.attributes[:name]).to eq("John")
    end

    it "returns coerced attributes after successful validation" do
      form = user_form_class.new(name: "John", email: "john@example.com", age: "25")
      form.valid?

      expect(form.attributes[:age]).to eq(25)
      expect(form.attributes[:admin]).to eq(false)
    end
  end

  describe "#persisted?" do
    it "returns false" do
      form = user_form_class.new
      expect(form.persisted?).to be false
    end
  end

  describe "#new_record?" do
    it "returns true" do
      form = user_form_class.new
      expect(form.new_record?).to be true
    end
  end

  describe "#to_h" do
    it "returns attributes hash" do
      form = user_form_class.new(name: "John", email: "john@example.com")
      form.valid?

      expect(form.to_h).to include(name: "John", email: "john@example.com")
    end
  end

  describe "#to_params" do
    it "returns string-keyed hash" do
      form = user_form_class.new(name: "John", email: "john@example.com")
      form.valid?

      expect(form.to_params).to include("name" => "John", "email" => "john@example.com")
    end
  end
end
