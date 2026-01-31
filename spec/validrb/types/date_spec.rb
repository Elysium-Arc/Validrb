# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Date do
  let(:type) { described_class.new }

  describe "#coerce" do
    it "passes through Date objects" do
      date = Date.new(2024, 1, 15)
      expect(type.coerce(date)).to eq(date)
    end

    it "converts Time to Date" do
      time = Time.new(2024, 1, 15, 12, 30, 0)
      expect(type.coerce(time)).to eq(Date.new(2024, 1, 15))
    end

    it "converts DateTime to Date" do
      datetime = DateTime.new(2024, 1, 15, 12, 30, 0)
      expect(type.coerce(datetime)).to eq(Date.new(2024, 1, 15))
    end

    it "parses ISO8601 date strings" do
      expect(type.coerce("2024-01-15")).to eq(Date.new(2024, 1, 15))
    end

    it "parses YYYY/MM/DD format" do
      expect(type.coerce("2024/01/15")).to eq(Date.new(2024, 1, 15))
    end

    it "parses YYYY/MM/DD format" do
      expect(type.coerce("2024/01/15")).to eq(Date.new(2024, 1, 15))
    end

    it "converts Unix timestamp to Date" do
      timestamp = Time.new(2024, 1, 15, 12, 0, 0).to_i
      expect(type.coerce(timestamp)).to eq(Date.new(2024, 1, 15))
    end

    it "strips whitespace from strings" do
      expect(type.coerce("  2024-01-15  ")).to eq(Date.new(2024, 1, 15))
    end

    it "fails for invalid date strings" do
      expect(type.coerce("not-a-date")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("2024-13-45")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for empty strings" do
      expect(type.coerce("")).to eq(Validrb::Types::COERCION_FAILED)
      expect(type.coerce("   ")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for nil" do
      expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for arrays" do
      expect(type.coerce([2024, 1, 15])).to eq(Validrb::Types::COERCION_FAILED)
    end
  end

  describe "#valid?" do
    it "returns true for Date objects" do
      expect(type.valid?(Date.new(2024, 1, 15))).to be true
    end

    it "returns false for DateTime objects" do
      expect(type.valid?(DateTime.new(2024, 1, 15))).to be false
    end

    it "returns false for Time objects" do
      expect(type.valid?(Time.new(2024, 1, 15))).to be false
    end

    it "returns false for strings" do
      expect(type.valid?("2024-01-15")).to be false
    end
  end

  describe "#call" do
    it "returns coerced Date on success" do
      value, errors = type.call("2024-01-15")

      expect(value).to eq(Date.new(2024, 1, 15))
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
    it "returns 'date'" do
      expect(type.type_name).to eq("date")
    end
  end

  describe "registry" do
    it "is registered as :date" do
      expect(Validrb::Types.lookup(:date)).to eq(described_class)
    end
  end
end
