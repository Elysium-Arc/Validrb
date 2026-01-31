# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Constraints::Enum do
  describe "with string values" do
    let(:constraint) { described_class.new(%w[admin user guest]) }

    it "passes for allowed values" do
      expect(constraint.valid?("admin")).to be true
      expect(constraint.valid?("user")).to be true
      expect(constraint.valid?("guest")).to be true
    end

    it "fails for disallowed values" do
      expect(constraint.valid?("superuser")).to be false
      expect(constraint.valid?("Admin")).to be false
      expect(constraint.valid?("")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("invalid")).to eq('must be one of: "admin", "user", "guest"')
    end
  end

  describe "with symbol values" do
    let(:constraint) { described_class.new(%i[active inactive pending]) }

    it "passes for allowed values" do
      expect(constraint.valid?(:active)).to be true
      expect(constraint.valid?(:inactive)).to be true
    end

    it "fails for disallowed values" do
      expect(constraint.valid?(:deleted)).to be false
      expect(constraint.valid?("active")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message(:invalid)).to eq("must be one of: :active, :inactive, :pending")
    end
  end

  describe "with integer values" do
    let(:constraint) { described_class.new([1, 2, 3]) }

    it "passes for allowed values" do
      expect(constraint.valid?(1)).to be true
      expect(constraint.valid?(2)).to be true
    end

    it "fails for disallowed values" do
      expect(constraint.valid?(4)).to be false
      expect(constraint.valid?("1")).to be false
    end
  end

  describe "with mixed values" do
    let(:constraint) { described_class.new([1, "two", :three]) }

    it "passes for any allowed value" do
      expect(constraint.valid?(1)).to be true
      expect(constraint.valid?("two")).to be true
      expect(constraint.valid?(:three)).to be true
    end

    it "fails for disallowed values" do
      expect(constraint.valid?("1")).to be false
      expect(constraint.valid?(2)).to be false
    end
  end

  describe "with single value" do
    let(:constraint) { described_class.new("only") }

    it "wraps single value in array" do
      expect(constraint.allowed).to eq(["only"])
    end

    it "validates against single value" do
      expect(constraint.valid?("only")).to be true
      expect(constraint.valid?("other")).to be false
    end
  end

  describe "validation" do
    it "requires at least one allowed value" do
      expect do
        described_class.new([])
      end.to raise_error(ArgumentError, /at least one allowed value/)
    end
  end

  describe "#call" do
    let(:constraint) { described_class.new(%w[yes no]) }

    it "returns empty array for valid value" do
      errors = constraint.call("yes")

      expect(errors).to be_empty
    end

    it "returns error for invalid value" do
      errors = constraint.call("maybe")

      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:enum)
    end

    it "includes path in error" do
      errors = constraint.call("maybe", path: [:answer])

      expect(errors.first.path).to eq([:answer])
    end
  end

  describe "registry" do
    it "is registered as :enum" do
      expect(Validrb::Constraints.lookup(:enum)).to eq(described_class)
    end
  end
end
