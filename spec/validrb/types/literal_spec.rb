# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Literal do
  describe "with single value" do
    let(:type) { described_class.new(values: "active") }

    describe "#valid?" do
      it "returns true for exact match" do
        expect(type.valid?("active")).to be true
      end

      it "returns false for non-match" do
        expect(type.valid?("inactive")).to be false
        expect(type.valid?(:active)).to be false
      end
    end

    describe "#call" do
      it "accepts exact value" do
        value, errors = type.call("active")
        expect(value).to eq("active")
        expect(errors).to be_empty
      end

      it "rejects non-matching value" do
        value, errors = type.call("inactive")
        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:type_error)
      end
    end

    describe "#type_name" do
      it "shows the literal value" do
        expect(type.type_name).to eq('"active"')
      end
    end
  end

  describe "with multiple values" do
    let(:type) { described_class.new(values: ["active", "pending", "completed"]) }

    describe "#valid?" do
      it "returns true for any matching value" do
        expect(type.valid?("active")).to be true
        expect(type.valid?("pending")).to be true
        expect(type.valid?("completed")).to be true
      end

      it "returns false for non-matching values" do
        expect(type.valid?("unknown")).to be false
      end
    end

    describe "#type_name" do
      it "shows all literal values" do
        expect(type.type_name).to eq('"active" | "pending" | "completed"')
      end
    end
  end

  describe "with numeric literals" do
    let(:type) { described_class.new(values: [1, 2, 3]) }

    it "matches exact numeric values" do
      expect(type.valid?(1)).to be true
      expect(type.valid?(2)).to be true
      expect(type.valid?(4)).to be false
    end

    it "does not coerce strings to numbers" do
      expect(type.valid?("1")).to be false
    end
  end

  describe "with symbol literals" do
    let(:type) { described_class.new(values: [:active, :inactive]) }

    it "matches symbols exactly" do
      expect(type.valid?(:active)).to be true
      expect(type.valid?(:inactive)).to be true
      expect(type.valid?("active")).to be false
    end
  end

  describe "registry" do
    it "is registered as :literal" do
      expect(Validrb::Types.lookup(:literal)).to eq(described_class)
    end
  end
end
