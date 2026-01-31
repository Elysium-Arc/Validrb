# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Serializer do
  describe ".dump" do
    it "serializes primitives" do
      expect(described_class.dump(42)).to eq(42)
      expect(described_class.dump("hello")).to eq("hello")
      expect(described_class.dump(true)).to eq(true)
      expect(described_class.dump(nil)).to eq(nil)
    end

    it "serializes symbols to strings" do
      expect(described_class.dump(:status)).to eq("status")
    end

    it "serializes BigDecimal to string" do
      expect(described_class.dump(BigDecimal("123.45"))).to eq("123.45")
    end

    it "serializes Date to ISO8601" do
      date = Date.new(2024, 1, 15)
      expect(described_class.dump(date)).to eq("2024-01-15")
    end

    it "serializes DateTime to ISO8601" do
      datetime = DateTime.new(2024, 1, 15, 10, 30, 0)
      expect(described_class.dump(datetime)).to include("2024-01-15")
    end

    it "serializes Time to ISO8601" do
      time = Time.new(2024, 1, 15, 10, 30, 0, "+00:00")
      expect(described_class.dump(time)).to include("2024-01-15")
    end

    it "serializes arrays recursively" do
      result = described_class.dump([:a, :b, Date.new(2024, 1, 15)])
      expect(result).to eq(["a", "b", "2024-01-15"])
    end

    it "serializes hashes with string keys" do
      result = described_class.dump({ name: "John", age: 30 })
      expect(result).to eq({ "name" => "John", "age" => 30 })
    end

    it "outputs JSON format" do
      result = described_class.dump({ name: "John" }, format: :json)
      expect(result).to eq('{"name":"John"}')
    end
  end
end

RSpec.describe Validrb::Success do
  describe "#dump" do
    it "serializes the success data" do
      result = Validrb::Success.new({ name: "John", created_at: Date.new(2024, 1, 15) })
      serialized = result.dump
      expect(serialized).to eq({ "name" => "John", "created_at" => "2024-01-15" })
    end

    it "outputs JSON format" do
      result = Validrb::Success.new({ name: "John" })
      expect(result.dump(format: :json)).to eq('{"name":"John"}')
    end
  end

  describe "#to_json" do
    it "returns JSON representation" do
      result = Validrb::Success.new({ name: "John" })
      expect(result.to_json).to eq('{"name":"John"}')
    end
  end
end

RSpec.describe Validrb::Failure do
  describe "#dump" do
    it "serializes the errors" do
      errors = [
        Validrb::Error.new(path: [:name], message: "is required", code: :required),
        Validrb::Error.new(path: [:email], message: "invalid format", code: :format)
      ]
      result = Validrb::Failure.new(errors)
      serialized = result.dump

      expect(serialized["errors"].size).to eq(2)
      expect(serialized["errors"].first["path"]).to eq(["name"])
      expect(serialized["errors"].first["message"]).to eq("is required")
      expect(serialized["errors"].first["code"]).to eq("required")
    end

    it "outputs JSON format" do
      errors = [Validrb::Error.new(path: [:name], message: "is required", code: :required)]
      result = Validrb::Failure.new(errors)
      json = result.dump(format: :json)
      expect(json).to include('"errors"')
      expect(json).to include('"name"')
    end
  end
end

RSpec.describe "Schema serialization" do
  let(:schema) do
    Validrb.schema do
      field :name, :string
      field :created_at, :date
      field :amount, :decimal
    end
  end

  describe "#dump" do
    it "parses and serializes valid data" do
      serialized = schema.dump({
        name: "Test",
        created_at: "2024-01-15",
        amount: "99.99"
      })

      expect(serialized["name"]).to eq("Test")
      expect(serialized["created_at"]).to eq("2024-01-15")
      expect(serialized["amount"]).to eq("99.99")
    end

    it "raises on invalid data" do
      expect {
        schema.dump({ name: nil })
      }.to raise_error(Validrb::ValidationError)
    end
  end

  describe "#safe_dump" do
    it "returns Success with serialized data" do
      result = schema.safe_dump({
        name: "Test",
        created_at: "2024-01-15",
        amount: "100"
      })

      expect(result).to be_a(Validrb::Success)
      expect(result.data["name"]).to eq("Test")
    end

    it "returns Failure for invalid data" do
      result = schema.safe_dump({})
      expect(result).to be_a(Validrb::Failure)
    end
  end
end
