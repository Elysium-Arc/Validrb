# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Constraints::Length do
  describe "with exact length" do
    let(:constraint) { described_class.new(exact: 5) }

    it "passes for exact length" do
      expect(constraint.valid?("hello")).to be true
      expect(constraint.valid?([1, 2, 3, 4, 5])).to be true
    end

    it "fails for different length" do
      expect(constraint.valid?("hi")).to be false
      expect(constraint.valid?("hello!")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("hi")).to eq("length must be exactly 5 (got 2)")
    end
  end

  describe "with min length" do
    let(:constraint) { described_class.new(min: 3) }

    it "passes for length >= min" do
      expect(constraint.valid?("abc")).to be true
      expect(constraint.valid?("hello")).to be true
    end

    it "fails for length < min" do
      expect(constraint.valid?("ab")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("ab")).to eq("length must be at least 3 (got 2)")
    end
  end

  describe "with max length" do
    let(:constraint) { described_class.new(max: 5) }

    it "passes for length <= max" do
      expect(constraint.valid?("hello")).to be true
      expect(constraint.valid?("hi")).to be true
    end

    it "fails for length > max" do
      expect(constraint.valid?("hello!")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("hello!")).to eq("length must be at most 5 (got 6)")
    end
  end

  describe "with min and max" do
    let(:constraint) { described_class.new(min: 3, max: 10) }

    it "passes for length in range" do
      expect(constraint.valid?("abc")).to be true
      expect(constraint.valid?("hello")).to be true
      expect(constraint.valid?("0123456789")).to be true
    end

    it "fails for length outside range" do
      expect(constraint.valid?("ab")).to be false
      expect(constraint.valid?("01234567890")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("ab")).to eq("length must be between 3 and 10 (got 2)")
    end
  end

  describe "with range" do
    let(:constraint) { described_class.new(range: 3..10) }

    it "passes for length in range" do
      expect(constraint.valid?("abc")).to be true
      expect(constraint.valid?("hello")).to be true
    end

    it "fails for length outside range" do
      expect(constraint.valid?("ab")).to be false
      expect(constraint.valid?("01234567890")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("ab")).to eq("length must be between 3 and 10 (got 2)")
    end
  end

  describe "with non-lengthable value" do
    let(:constraint) { described_class.new(exact: 5) }

    it "fails for values without length" do
      expect(constraint.valid?(42)).to be false
    end
  end

  describe "validation" do
    it "requires at least one option" do
      expect do
        described_class.new
      end.to raise_error(ArgumentError, /requires at least one/)
    end
  end

  describe "#call" do
    let(:constraint) { described_class.new(exact: 5) }

    it "returns empty array for valid value" do
      errors = constraint.call("hello")

      expect(errors).to be_empty
    end

    it "returns error for invalid value" do
      errors = constraint.call("hi")

      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:length)
    end
  end

  describe "registry" do
    it "is registered as :length" do
      expect(Validrb::Constraints.lookup(:length)).to eq(described_class)
    end
  end
end
