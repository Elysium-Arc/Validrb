# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Float do
  let(:type) { described_class.new }

  describe "#coerce" do
    it "passes through finite floats" do
      expect(type.coerce(3.14)).to eq(3.14)
    end

    it "converts integers to floats" do
      expect(type.coerce(42)).to eq(42.0)
    end

    it "converts string floats" do
      expect(type.coerce("3.14")).to eq(3.14)
      expect(type.coerce("-3.14")).to eq(-3.14)
    end

    it "converts string integers to floats" do
      expect(type.coerce("42")).to eq(42.0)
    end

    it "converts string with whitespace" do
      expect(type.coerce("  3.14  ")).to eq(3.14)
    end

    it "fails for non-numeric strings" do
      expect(type.coerce("hello")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("3.14abc")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for empty strings" do
      expect(type.coerce("")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("   ")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for infinity" do
      expect(type.coerce(Float::INFINITY)).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce(-Float::INFINITY)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for NaN" do
      expect(type.coerce(Float::NAN)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for arrays" do
      expect(type.coerce([3.14])).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for nil" do
      expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
    end
  end

  describe "#valid?" do
    it "returns true for finite floats" do
      expect(type.valid?(3.14)).to be true
      expect(type.valid?(-3.14)).to be true
      expect(type.valid?(0.0)).to be true
    end

    it "returns false for infinity" do
      expect(type.valid?(Float::INFINITY)).to be false
    end

    it "returns false for NaN" do
      expect(type.valid?(Float::NAN)).to be false
    end

    it "returns false for non-floats" do
      expect(type.valid?(42)).to be false
      expect(type.valid?("3.14")).to be false
    end
  end

  describe "#call" do
    it "returns coerced value on success" do
      value, errors = type.call("3.14")

      expect(value).to eq(3.14)
      expect(errors).to be_empty
    end

    it "returns error on failure" do
      value, errors = type.call("not a number")

      expect(value).to be_nil
      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:type_error)
    end
  end

  describe "#type_name" do
    it "returns 'float'" do
      expect(type.type_name).to eq("float")
    end
  end
end
