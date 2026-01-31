# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Validrb::Types::Decimal do
  let(:type) { described_class.new }

  describe "#coerce" do
    it "passes through BigDecimal objects" do
      decimal = BigDecimal("123.45")
      expect(type.coerce(decimal)).to eq(decimal)
    end

    it "converts integers to BigDecimal" do
      result = type.coerce(42)
      expect(result).to be_a(BigDecimal)
      expect(result).to eq(BigDecimal("42"))
    end

    it "converts floats to BigDecimal" do
      result = type.coerce(3.14)
      expect(result).to be_a(BigDecimal)
      expect(result.to_f).to be_within(0.001).of(3.14)
    end

    it "parses decimal strings" do
      result = type.coerce("123.45")
      expect(result).to be_a(BigDecimal)
      expect(result).to eq(BigDecimal("123.45"))
    end

    it "parses negative decimal strings" do
      result = type.coerce("-123.45")
      expect(result).to be_a(BigDecimal)
      expect(result).to eq(BigDecimal("-123.45"))
    end

    it "parses integer strings" do
      result = type.coerce("42")
      expect(result).to be_a(BigDecimal)
      expect(result).to eq(BigDecimal("42"))
    end

    it "strips whitespace from strings" do
      result = type.coerce("  123.45  ")
      expect(result).to be_a(BigDecimal)
      expect(result).to eq(BigDecimal("123.45"))
    end

    it "converts Rational to BigDecimal" do
      result = type.coerce(Rational(1, 3))
      expect(result).to be_a(BigDecimal)
    end

    it "fails for non-numeric strings" do
      expect(type.coerce("not-a-number")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("12.34.56")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("$123.45")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for empty strings" do
      expect(type.coerce("")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("   ")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for nil" do
      expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for infinity" do
      expect(type.coerce(Float::INFINITY)).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce(-Float::INFINITY)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for NaN" do
      expect(type.coerce(Float::NAN)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for arrays" do
      expect(type.coerce([123.45])).to eq(Validrb::Types::COERCION_FAILED)
    end
  end

  describe "#valid?" do
    it "returns true for finite BigDecimal" do
      expect(type.valid?(BigDecimal("123.45"))).to be true
    end

    it "returns false for BigDecimal infinity" do
      expect(type.valid?(BigDecimal("Infinity"))).to be false
    end

    it "returns false for BigDecimal NaN" do
      expect(type.valid?(BigDecimal("NaN"))).to be false
    end

    it "returns false for floats" do
      expect(type.valid?(123.45)).to be false
    end

    it "returns false for integers" do
      expect(type.valid?(42)).to be false
    end
  end

  describe "#call" do
    it "returns coerced BigDecimal on success" do
      value, errors = type.call("123.45")

      expect(value).to be_a(BigDecimal)
      expect(value).to eq(BigDecimal("123.45"))
      expect(errors).to be_empty
    end

    it "returns error on failure" do
      value, errors = type.call("invalid")

      expect(value).to be_nil
      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:type_error)
    end
  end

  describe "#type_name" do
    it "returns 'decimal'" do
      expect(type.type_name).to eq("decimal")
    end
  end

  describe "registry" do
    it "is registered as :decimal" do
      expect(Validrb::Types.lookup(:decimal)).to eq(described_class)
    end

    it "is registered as :bigdecimal" do
      expect(Validrb::Types.lookup(:bigdecimal)).to eq(described_class)
    end
  end

  describe "precision" do
    it "maintains precision for monetary values" do
      result = type.coerce("19.99")
      expect(result.to_s("F")).to eq("19.99")
    end

    it "handles large numbers precisely" do
      result = type.coerce("123456789012345678901234567890.12345")
      expect(result).to be_a(BigDecimal)
    end
  end
end
