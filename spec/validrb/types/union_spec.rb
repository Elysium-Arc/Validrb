# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Union do
  describe "with symbol types" do
    # Note: Union tries types in order, so put more specific types first
    let(:type) { described_class.new(types: [:integer, :string]) }

    describe "#coerce" do
      it "coerces to first matching type" do
        expect(type.coerce(42)).to eq(42)
        expect(type.coerce("hello")).to eq("hello")
      end

      it "coerces string that looks like integer to integer (first match)" do
        expect(type.coerce("42")).to eq(42)
      end

      it "fails when no type matches" do
        expect(type.coerce([1, 2, 3])).to eq(Validrb::Types::COERCION_FAILED)
      end
    end

    describe "#valid?" do
      it "returns true if any type matches" do
        expect(type.valid?("hello")).to be true
        expect(type.valid?(42)).to be true
      end

      it "returns false if no type matches" do
        expect(type.valid?([1, 2, 3])).to be false
      end
    end

    describe "#call" do
      it "returns success for matching types" do
        value, errors = type.call("hello")
        expect(value).to eq("hello")
        expect(errors).to be_empty

        value, errors = type.call(42)
        expect(value).to eq(42)
        expect(errors).to be_empty
      end

      it "returns union error when no type matches" do
        value, errors = type.call([1, 2, 3])
        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:union_type_error)
      end
    end

    describe "#type_name" do
      it "shows all types" do
        expect(type.type_name).to eq("union<integer | string>")
      end
    end
  end

  describe "with integer and float" do
    let(:type) { described_class.new(types: [:integer, :float]) }

    it "coerces string to integer first" do
      value, errors = type.call("42")
      expect(value).to eq(42)
      expect(errors).to be_empty
    end

    it "coerces decimal string to float" do
      value, errors = type.call("3.14")
      expect(value).to eq(3.14)
      expect(errors).to be_empty
    end
  end

  describe "with boolean and string" do
    let(:type) { described_class.new(types: [:boolean, :string]) }

    it "coerces 'true' to boolean first" do
      value, errors = type.call("true")
      expect(value).to be true
      expect(errors).to be_empty
    end

    it "coerces non-boolean string" do
      value, errors = type.call("hello")
      expect(value).to eq("hello")
      expect(errors).to be_empty
    end
  end

  describe "registry" do
    it "is registered as :union" do
      expect(Validrb::Types.lookup(:union)).to eq(described_class)
    end
  end
end
