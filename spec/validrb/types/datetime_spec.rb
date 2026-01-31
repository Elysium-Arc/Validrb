# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::DateTime do
  let(:type) { described_class.new }

  describe "#coerce" do
    it "passes through DateTime objects" do
      datetime = DateTime.new(2024, 1, 15, 12, 30, 0)
      expect(type.coerce(datetime)).to eq(datetime)
    end

    it "converts Time to DateTime" do
      time = Time.new(2024, 1, 15, 12, 30, 0)
      result = type.coerce(time)
      expect(result).to be_a(DateTime)
      expect(result.year).to eq(2024)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
    end

    it "converts Date to DateTime" do
      date = Date.new(2024, 1, 15)
      result = type.coerce(date)
      expect(result).to be_a(DateTime)
      expect(result.year).to eq(2024)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
    end

    it "parses ISO8601 datetime strings" do
      result = type.coerce("2024-01-15T12:30:00")
      expect(result).to be_a(DateTime)
      expect(result.year).to eq(2024)
      expect(result.hour).to eq(12)
      expect(result.min).to eq(30)
    end

    it "parses ISO8601 with timezone" do
      result = type.coerce("2024-01-15T12:30:00+05:00")
      expect(result).to be_a(DateTime)
      expect(result.offset).to eq(Rational(5, 24))
    end

    it "parses ISO8601 with Z timezone" do
      result = type.coerce("2024-01-15T12:30:00Z")
      expect(result).to be_a(DateTime)
      expect(result.offset).to eq(0)
    end

    it "converts Unix timestamp to DateTime" do
      timestamp = Time.new(2024, 1, 15, 12, 0, 0).to_i
      result = type.coerce(timestamp)
      expect(result).to be_a(DateTime)
      expect(result.year).to eq(2024)
    end

    it "converts float timestamp to DateTime" do
      timestamp = Time.new(2024, 1, 15, 12, 0, 0).to_f
      result = type.coerce(timestamp)
      expect(result).to be_a(DateTime)
    end

    it "strips whitespace from strings" do
      result = type.coerce("  2024-01-15T12:30:00  ")
      expect(result).to be_a(DateTime)
    end

    it "fails for invalid datetime strings" do
      expect(type.coerce("not-a-datetime")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for empty strings" do
      expect(type.coerce("")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for nil" do
      expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
    end
  end

  describe "#valid?" do
    it "returns true for DateTime objects" do
      expect(type.valid?(DateTime.new(2024, 1, 15))).to be true
    end

    it "returns false for Date objects" do
      expect(type.valid?(Date.new(2024, 1, 15))).to be false
    end

    it "returns false for Time objects" do
      expect(type.valid?(Time.new(2024, 1, 15))).to be false
    end
  end

  describe "#call" do
    it "returns coerced DateTime on success" do
      value, errors = type.call("2024-01-15T12:30:00")

      expect(value).to be_a(DateTime)
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
    it "returns 'datetime'" do
      expect(type.type_name).to eq("datetime")
    end
  end

  describe "registry" do
    it "is registered as :datetime" do
      expect(Validrb::Types.lookup(:datetime)).to eq(described_class)
    end

    it "is registered as :date_time" do
      expect(Validrb::Types.lookup(:date_time)).to eq(described_class)
    end
  end
end
