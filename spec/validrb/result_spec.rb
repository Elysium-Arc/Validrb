# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Success do
  let(:data) { { name: "John", age: 30 } }
  let(:success) { described_class.new(data) }

  describe "#initialize" do
    it "stores the data" do
      expect(success.data).to eq(data)
    end

    it "freezes the result" do
      expect(success).to be_frozen
    end
  end

  describe "#success?" do
    it "returns true" do
      expect(success.success?).to be true
    end
  end

  describe "#failure?" do
    it "returns false" do
      expect(success.failure?).to be false
    end
  end

  describe "#errors" do
    it "returns empty error collection" do
      expect(success.errors).to be_a(Validrb::ErrorCollection)
      expect(success.errors).to be_empty
    end
  end

  describe "#value_or" do
    it "returns the data" do
      expect(success.value_or("default")).to eq(data)
    end

    it "ignores the default" do
      expect(success.value_or { "computed" }).to eq(data)
    end
  end

  describe "#map" do
    it "transforms the data" do
      result = success.map { |d| d[:name].upcase }

      expect(result).to be_a(described_class)
      expect(result.data).to eq("JOHN")
    end
  end

  describe "#flat_map" do
    it "returns the block result" do
      result = success.flat_map { |d| described_class.new(d[:name]) }

      expect(result).to be_a(described_class)
      expect(result.data).to eq("John")
    end
  end

  describe "equality" do
    it "considers successes with same data equal" do
      success1 = described_class.new({ a: 1 })
      success2 = described_class.new({ a: 1 })

      expect(success1).to eq(success2)
      expect(success1.hash).to eq(success2.hash)
    end

    it "considers successes with different data unequal" do
      success1 = described_class.new({ a: 1 })
      success2 = described_class.new({ a: 2 })

      expect(success1).not_to eq(success2)
    end
  end
end

RSpec.describe Validrb::Failure do
  let(:error) { Validrb::Error.new(path: [:name], message: "is required") }
  let(:errors) { Validrb::ErrorCollection.new([error]) }
  let(:failure) { described_class.new(errors) }

  describe "#initialize" do
    it "stores the errors" do
      expect(failure.errors).to eq(errors)
    end

    it "wraps array in ErrorCollection" do
      failure = described_class.new([error])

      expect(failure.errors).to be_a(Validrb::ErrorCollection)
    end

    it "freezes the result" do
      expect(failure).to be_frozen
    end
  end

  describe "#success?" do
    it "returns false" do
      expect(failure.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns true" do
      expect(failure.failure?).to be true
    end
  end

  describe "#data" do
    it "returns nil" do
      expect(failure.data).to be_nil
    end
  end

  describe "#value_or" do
    it "returns the default value" do
      expect(failure.value_or("default")).to eq("default")
    end

    it "calls block with errors" do
      result = failure.value_or { |e| "Error: #{e.first.message}" }

      expect(result).to eq("Error: is required")
    end
  end

  describe "#map" do
    it "returns self without calling block" do
      called = false
      result = failure.map { called = true }

      expect(result).to eq(failure)
      expect(called).to be false
    end
  end

  describe "#flat_map" do
    it "returns self without calling block" do
      called = false
      result = failure.flat_map { called = true }

      expect(result).to eq(failure)
      expect(called).to be false
    end
  end

  describe "equality" do
    it "considers failures with same errors equal" do
      failure1 = described_class.new([error])
      failure2 = described_class.new([error])

      expect(failure1).to eq(failure2)
      expect(failure1.hash).to eq(failure2.hash)
    end
  end
end
