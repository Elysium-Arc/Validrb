# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::Time do
  let(:type) { described_class.new }

  describe "#coerce" do
    it "passes through Time objects" do
      time = Time.new(2024, 1, 15, 12, 30, 0)
      expect(type.coerce(time)).to eq(time)
    end

    it "converts DateTime to Time" do
      datetime = DateTime.new(2024, 1, 15, 12, 30, 0)
      result = type.coerce(datetime)
      expect(result).to be_a(Time)
      expect(result.year).to eq(2024)
      expect(result.hour).to eq(12)
    end

    it "converts Date to Time" do
      date = Date.new(2024, 1, 15)
      result = type.coerce(date)
      expect(result).to be_a(Time)
      expect(result.year).to eq(2024)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
    end

    it "parses ISO8601 time strings" do
      result = type.coerce("2024-01-15T12:30:00")
      expect(result).to be_a(Time)
      expect(result.year).to eq(2024)
      expect(result.hour).to eq(12)
    end

    it "parses ISO8601 with timezone" do
      result = type.coerce("2024-01-15T12:30:00Z")
      expect(result).to be_a(Time)
      expect(result.utc?).to be true
    end

    it "converts Unix timestamp to Time" do
      original = Time.new(2024, 1, 15, 12, 0, 0)
      result = type.coerce(original.to_i)
      expect(result).to be_a(Time)
      expect(result.year).to eq(2024)
    end

    it "converts float timestamp to Time" do
      original = Time.new(2024, 1, 15, 12, 0, 0)
      result = type.coerce(original.to_f)
      expect(result).to be_a(Time)
    end

    it "strips whitespace from strings" do
      result = type.coerce("  2024-01-15T12:30:00  ")
      expect(result).to be_a(Time)
    end

    it "fails for invalid time strings" do
      expect(type.coerce("not-a-time")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for empty strings" do
      expect(type.coerce("")).to eq(Validrb::Types::COERCION_FAILED)
    end

    it "fails for nil" do
      expect(type.coerce(nil)).to eq(Validrb::Types::COERCION_FAILED)
    end
  end

  describe "#valid?" do
    it "returns true for Time objects" do
      expect(type.valid?(Time.new(2024, 1, 15))).to be true
    end

    it "returns false for DateTime objects" do
      expect(type.valid?(DateTime.new(2024, 1, 15))).to be false
    end

    it "returns false for Date objects" do
      expect(type.valid?(Date.new(2024, 1, 15))).to be false
    end
  end

  describe "#call" do
    it "returns coerced Time on success" do
      value, errors = type.call("2024-01-15T12:30:00")

      expect(value).to be_a(Time)
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
    it "returns 'time'" do
      expect(type.type_name).to eq("time")
    end
  end

  describe "registry" do
    it "is registered as :time" do
      expect(Validrb::Types.lookup(:time)).to eq(described_class)
    end
  end
end
