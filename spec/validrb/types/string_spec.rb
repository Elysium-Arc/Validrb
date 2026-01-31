# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::String do
  let(:type) { described_class.new }

  describe "#coerce" do
    it "passes through strings" do
      expect(type.coerce("hello")).to eq("hello")
    end

    it "converts symbols to strings" do
      expect(type.coerce(:hello)).to eq("hello")
    end

    it "converts integers to strings" do
      expect(type.coerce(42)).to eq("42")
    end

    it "converts floats to strings" do
      expect(type.coerce(3.14)).to eq("3.14")
    end

    it "fails for arrays" do
      expect(type.coerce([1, 2, 3])).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for hashes" do
      expect(type.coerce({ a: 1 })).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for nil" do
      expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
    end
  end

  describe "#valid?" do
    it "returns true for strings" do
      expect(type.valid?("hello")).to be true
    end

    it "returns false for non-strings" do
      expect(type.valid?(42)).to be false
      expect(type.valid?(:symbol)).to be false
    end
  end

  describe "#call" do
    it "returns coerced value on success" do
      value, errors = type.call(:hello)

      expect(value).to eq("hello")
      expect(errors).to be_empty
    end

    it "returns error on failure" do
      value, errors = type.call([1, 2, 3])

      expect(value).to be_nil
      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:type_error)
    end

    it "includes path in error" do
      _value, errors = type.call([1, 2, 3], path: [:user, :name])

      expect(errors.first.path).to eq([:user, :name])
    end
  end

  describe "#type_name" do
    it "returns 'string'" do
      expect(type.type_name).to eq("string")
    end
  end
end
