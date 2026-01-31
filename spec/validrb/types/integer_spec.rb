# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Integer do
  let(:type) { described_class.new }

  describe "#coerce" do
    it "passes through integers" do
      expect(type.coerce(42)).to eq(42)
    end

    it "converts string integers" do
      expect(type.coerce("42")).to eq(42)
      expect(type.coerce("-42")).to eq(-42)
    end

    it "converts string with whitespace" do
      expect(type.coerce("  42  ")).to eq(42)
    end

    it "converts whole floats" do
      expect(type.coerce(42.0)).to eq(42)
    end

    it "converts string whole floats" do
      expect(type.coerce("42.0")).to eq(42)
      expect(type.coerce("42.00")).to eq(42)
    end

    it "fails for non-whole floats" do
      expect(type.coerce(42.5)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for non-numeric strings" do
      expect(type.coerce("hello")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("42abc")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for empty strings" do
      expect(type.coerce("")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("   ")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for arrays" do
      expect(type.coerce([42])).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for nil" do
      expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for infinity" do
      expect(type.coerce(Float::INFINITY)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for NaN" do
      expect(type.coerce(Float::NAN)).to eq(Validrb::Types::COERCION_FAILED)
    end
  end

  describe "#valid?" do
    it "returns true for integers" do
      expect(type.valid?(42)).to be true
      expect(type.valid?(-42)).to be true
      expect(type.valid?(0)).to be true
    end

    it "returns false for non-integers" do
      expect(type.valid?(42.0)).to be false
      expect(type.valid?("42")).to be false
    end
  end

  describe "#call" do
    it "returns coerced value on success" do
      value, errors = type.call("42")

      expect(value).to eq(42)
      expect(errors).to be_empty
    end

    it "returns error on failure" do
      value, errors = type.call("not a number")

      expect(value).to be_nil
      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:type_error)
      expect(errors.first.message).to include("cannot coerce")
    end
  end

  describe "#type_name" do
    it "returns 'integer'" do
      expect(type.type_name).to eq("integer")
    end
  end
end
