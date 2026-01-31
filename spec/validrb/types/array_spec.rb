# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Array do
  describe "without item type" do
    let(:type) { described_class.new }

    describe "#coerce" do
      it "passes through arrays" do
        expect(type.coerce([1, 2, 3])).to eq([1, 2, 3])
      end

      it "fails for non-arrays" do
        expect(type.coerce("hello")).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce(42)).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce({ a: 1 })).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
      end
    end

    describe "#valid?" do
      it "returns true for arrays" do
        expect(type.valid?([])).to be true
        expect(type.valid?([1, 2, 3])).to be true
      end

      it "returns false for non-arrays" do
        expect(type.valid?("hello")).to be false
      end
    end

    describe "#call" do
      it "returns the array unchanged" do
        value, errors = type.call([1, "two", :three])

        expect(value).to eq([1, "two", :three])
        expect(errors).to be_empty
      end

      it "returns error for non-array" do
        value, errors = type.call("not an array")

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:type_error)
      end
    end

    describe "#type_name" do
      it "returns 'array'" do
        expect(type.type_name).to eq("array")
      end
    end
  end

  describe "with item type" do
    let(:type) { described_class.new(of: :integer) }

    describe "#call" do
      it "coerces all items" do
        value, errors = type.call(["1", "2", "3"])

        expect(value).to eq([1, 2, 3])
        expect(errors).to be_empty
      end

      it "returns error for invalid item" do
        value, errors = type.call(["1", "invalid", "3"])

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.path).to eq([1])
        expect(errors.first.code).to eq(:type_error)
      end

      it "collects all item errors" do
        value, errors = type.call(["invalid1", "invalid2"])

        expect(value).to be_nil
        expect(errors.size).to eq(2)
        expect(errors.map { |e| e.path }).to eq([[0], [1]])
      end

      it "includes parent path in error" do
        value, errors = type.call(["invalid"], path: [:items])

        expect(errors.first.path).to eq([:items, 0])
      end
    end

    describe "#type_name" do
      it "includes item type" do
        expect(type.type_name).to eq("array<integer>")
      end
    end
  end

  describe "with nested array type" do
    let(:type) { described_class.new(of: :string) }

    it "validates nested items" do
      value, errors = type.call([:a, :b, :c])

      expect(value).to eq(["a", "b", "c"])
      expect(errors).to be_empty
    end
  end
end
