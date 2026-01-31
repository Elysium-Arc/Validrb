# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Constraints::Min do
  describe "with numbers" do
    let(:constraint) { described_class.new(10) }

    it "passes for values >= min" do
      expect(constraint.valid?(10)).to be true
      expect(constraint.valid?(15)).to be true
      expect(constraint.valid?(100)).to be true
    end

    it "fails for values < min" do
      expect(constraint.valid?(9)).to be false
      expect(constraint.valid?(0)).to be false
      expect(constraint.valid?(-5)).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message(5)).to eq("must be at least 10")
    end
  end

  describe "with strings" do
    let(:constraint) { described_class.new(3) }

    it "passes for strings with length >= min" do
      expect(constraint.valid?("abc")).to be true
      expect(constraint.valid?("hello")).to be true
    end

    it "fails for strings with length < min" do
      expect(constraint.valid?("ab")).to be false
      expect(constraint.valid?("")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("ab")).to eq("length must be at least 3 (got 2)")
    end
  end

  describe "with arrays" do
    let(:constraint) { described_class.new(2) }

    it "passes for arrays with length >= min" do
      expect(constraint.valid?([1, 2])).to be true
      expect(constraint.valid?([1, 2, 3])).to be true
    end

    it "fails for arrays with length < min" do
      expect(constraint.valid?([1])).to be false
      expect(constraint.valid?([])).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message([1])).to eq("length must be at least 2 (got 1)")
    end
  end

  describe "#call" do
    let(:constraint) { described_class.new(5) }

    it "returns empty array for valid value" do
      errors = constraint.call(10)

      expect(errors).to be_empty
    end

    it "returns error for invalid value" do
      errors = constraint.call(3)

      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:min)
    end

    it "includes path in error" do
      errors = constraint.call(3, path: [:count])

      expect(errors.first.path).to eq([:count])
    end
  end

  describe "error_code" do
    it "returns :min" do
      constraint = described_class.new(5)

      expect(constraint.error_code).to eq(:min)
    end
  end

  describe "registry" do
    it "is registered as :min" do
      expect(Validrb::Constraints.lookup(:min)).to eq(described_class)
    end
  end
end
