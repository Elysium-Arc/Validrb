# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Constraints::Max do
  describe "with numbers" do
    let(:constraint) { described_class.new(100) }

    it "passes for values <= max" do
      expect(constraint.valid?(100)).to be true
      expect(constraint.valid?(50)).to be true
      expect(constraint.valid?(0)).to be true
    end

    it "fails for values > max" do
      expect(constraint.valid?(101)).to be false
      expect(constraint.valid?(1000)).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message(150)).to eq("must be at most 100")
    end
  end

  describe "with strings" do
    let(:constraint) { described_class.new(5) }

    it "passes for strings with length <= max" do
      expect(constraint.valid?("hello")).to be true
      expect(constraint.valid?("hi")).to be true
      expect(constraint.valid?("")).to be true
    end

    it "fails for strings with length > max" do
      expect(constraint.valid?("hello!")).to be false
      expect(constraint.valid?("hello world")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("hello!")).to eq("length must be at most 5 (got 6)")
    end
  end

  describe "with arrays" do
    let(:constraint) { described_class.new(3) }

    it "passes for arrays with length <= max" do
      expect(constraint.valid?([1, 2, 3])).to be true
      expect(constraint.valid?([1])).to be true
      expect(constraint.valid?([])).to be true
    end

    it "fails for arrays with length > max" do
      expect(constraint.valid?([1, 2, 3, 4])).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message([1, 2, 3, 4])).to eq("length must be at most 3 (got 4)")
    end
  end

  describe "#call" do
    let(:constraint) { described_class.new(10) }

    it "returns empty array for valid value" do
      errors = constraint.call(5)

      expect(errors).to be_empty
    end

    it "returns error for invalid value" do
      errors = constraint.call(15)

      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:max)
    end

    it "includes path in error" do
      errors = constraint.call(15, path: [:count])

      expect(errors.first.path).to eq([:count])
    end
  end

  describe "error_code" do
    it "returns :max" do
      constraint = described_class.new(10)

      expect(constraint.error_code).to eq(:max)
    end
  end

  describe "registry" do
    it "is registered as :max" do
      expect(Validrb::Constraints.lookup(:max)).to eq(described_class)
    end
  end
end
