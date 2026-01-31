# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Boolean do
  let(:type) { described_class.new }

  describe "#coerce" do
    context "truthy values" do
      it "coerces true to true" do
        expect(type.coerce(true)).to be true
      end

      it "coerces 1 to true" do
        expect(type.coerce(1)).to be true
      end

      it "coerces '1' to true" do
        expect(type.coerce("1")).to be true
      end

      it "coerces 'true' to true" do
        expect(type.coerce("true")).to be true
        expect(type.coerce("TRUE")).to be true
        expect(type.coerce("True")).to be true
      end

      it "coerces 'yes' to true" do
        expect(type.coerce("yes")).to be true
        expect(type.coerce("YES")).to be true
      end

      it "coerces 'on' to true" do
        expect(type.coerce("on")).to be true
        expect(type.coerce("ON")).to be true
      end

      it "coerces 't' to true" do
        expect(type.coerce("t")).to be true
        expect(type.coerce("T")).to be true
      end

      it "coerces 'y' to true" do
        expect(type.coerce("y")).to be true
        expect(type.coerce("Y")).to be true
      end
    end

    context "falsy values" do
      it "coerces false to false" do
        expect(type.coerce(false)).to be false
      end

      it "coerces 0 to false" do
        expect(type.coerce(0)).to be false
      end

      it "coerces '0' to false" do
        expect(type.coerce("0")).to be false
      end

      it "coerces 'false' to false" do
        expect(type.coerce("false")).to be false
        expect(type.coerce("FALSE")).to be false
        expect(type.coerce("False")).to be false
      end

      it "coerces 'no' to false" do
        expect(type.coerce("no")).to be false
        expect(type.coerce("NO")).to be false
      end

      it "coerces 'off' to false" do
        expect(type.coerce("off")).to be false
        expect(type.coerce("OFF")).to be false
      end

      it "coerces 'f' to false" do
        expect(type.coerce("f")).to be false
        expect(type.coerce("F")).to be false
      end

      it "coerces 'n' to false" do
        expect(type.coerce("n")).to be false
        expect(type.coerce("N")).to be false
      end
    end

    context "invalid values" do
      it "fails for nil" do
        expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
      end

      it "fails for arbitrary strings" do
        expect(type.coerce("maybe")).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce("")).to eq(Validrb::Types::COERCION_FAILED)
      end

      it "fails for other numbers" do
        expect(type.coerce(2)).to eq(Validrb::Types::COERCION_FAILED)
        expect(type.coerce(-1)).to eq(Validrb::Types::COERCION_FAILED)
      end

      it "fails for arrays" do
        expect(type.coerce([true])).to eq(Validrb::Types::COERCION_FAILED)
      end
    end
  end

  describe "#valid?" do
    it "returns true for true" do
      expect(type.valid?(true)).to be true
    end

    it "returns true for false" do
      expect(type.valid?(false)).to be true
    end

    it "returns false for non-booleans" do
      expect(type.valid?(1)).to be false
      expect(type.valid?("true")).to be false
      expect(type.valid?(nil)).to be false
    end
  end

  describe "#call" do
    it "returns coerced value on success" do
      value, errors = type.call("true")

      expect(value).to be true
      expect(errors).to be_empty
    end

    it "returns error on failure" do
      value, errors = type.call("maybe")

      expect(value).to be_nil
      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:type_error)
    end
  end

  describe "#type_name" do
    it "returns 'boolean'" do
      expect(type.type_name).to eq("boolean")
    end
  end

  describe "registry" do
    it "is registered as :boolean" do
      expect(Validrb::Types.lookup(:boolean)).to eq(described_class)
    end

    it "is registered as :bool" do
      expect(Validrb::Types.lookup(:bool)).to eq(described_class)
    end
  end
end
