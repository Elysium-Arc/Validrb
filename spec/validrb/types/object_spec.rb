# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Object do
  describe "without schema" do
    let(:type) { described_class.new }

    describe "#coerce" do
      it "passes through hashes" do
        expect(type.coerce({ a: 1 })).to eq({ a: 1 })
      end

      it "fails for non-hashes" do
        expect(type.coerce("hello")).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce([1, 2])).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce(42)).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
      end
    end

    describe "#valid?" do
      it "returns true for hashes" do
        expect(type.valid?({})).to be true
        expect(type.valid?({ a: 1 })).to be true
      end

      it "returns false for non-hashes" do
        expect(type.valid?("hello")).to be false
      end
    end

    describe "#call" do
      it "returns the hash unchanged" do
        value, errors = type.call({ a: 1, b: "two" })

        expect(value).to eq({ a: 1, b: "two" })
        expect(errors).to be_empty
      end

      it "returns error for non-hash" do
        value, errors = type.call("not a hash")

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:type_error)
      end
    end

    describe "#type_name" do
      it "returns 'object'" do
        expect(type.type_name).to eq("object")
      end
    end
  end

  describe "with schema" do
    let(:nested_schema) do
      Validrb::Schema.new do
        field :street, :string
        field :city, :string
      end
    end

    let(:type) { described_class.new(schema: nested_schema) }

    describe "#call" do
      it "validates against nested schema" do
        value, errors = type.call({ street: "123 Main St", city: "Boston" })

        expect(value).to eq({ street: "123 Main St", city: "Boston" })
        expect(errors).to be_empty
      end

      it "coerces nested values" do
        value, errors = type.call({ street: :main_street, city: :boston })

        expect(value).to eq({ street: "main_street", city: "boston" })
        expect(errors).to be_empty
      end

      it "returns errors for invalid nested data" do
        value, errors = type.call({ street: "123 Main St" })

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.path).to eq([:city])
      end

      it "includes parent path in nested errors" do
        value, errors = type.call({ street: "123 Main St" }, path: [:address])

        expect(errors.first.path).to eq([:address, :city])
      end
    end
  end

  describe "registry" do
    it "is registered as :object" do
      expect(Validrb::Types.lookup(:object)).to eq(described_class)
    end

    it "is registered as :hash" do
      expect(Validrb::Types.lookup(:hash)).to eq(described_class)
    end
  end
end
