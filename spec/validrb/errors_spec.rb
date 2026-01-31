# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Error do
  describe "#initialize" do
    it "creates an error with path, message, and code" do
      error = described_class.new(path: [:user, :name], message: "is required", code: :required)

      expect(error.path).to eq([:user, :name])
      expect(error.message).to eq("is required")
      expect(error.code).to eq(:required)
    end

    it "normalizes path to array" do
      error = described_class.new(path: :name, message: "invalid")

      expect(error.path).to eq([:name])
    end

    it "allows nil code" do
      error = described_class.new(path: [], message: "error")

      expect(error.code).to be_nil
    end

    it "freezes the error" do
      error = described_class.new(path: [:name], message: "invalid")

      expect(error).to be_frozen
    end
  end

  describe "#full_path" do
    it "returns dot-separated path" do
      error = described_class.new(path: [:user, :address, :city], message: "invalid")

      expect(error.full_path).to eq("user.address.city")
    end

    it "returns empty string for empty path" do
      error = described_class.new(path: [], message: "invalid")

      expect(error.full_path).to eq("")
    end
  end

  describe "#to_s" do
    it "includes path and message" do
      error = described_class.new(path: [:name], message: "is required")

      expect(error.to_s).to eq("name: is required")
    end

    it "omits path prefix when empty" do
      error = described_class.new(path: [], message: "invalid input")

      expect(error.to_s).to eq("invalid input")
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      error = described_class.new(path: [:name], message: "invalid", code: :format)

      expect(error.to_h).to eq({ path: [:name], message: "invalid", code: :format })
    end

    it "omits nil code" do
      error = described_class.new(path: [:name], message: "invalid")

      expect(error.to_h).to eq({ path: [:name], message: "invalid" })
    end
  end

  describe "equality" do
    it "considers errors with same attributes equal" do
      error1 = described_class.new(path: [:name], message: "invalid", code: :format)
      error2 = described_class.new(path: [:name], message: "invalid", code: :format)

      expect(error1).to eq(error2)
      expect(error1.hash).to eq(error2.hash)
    end

    it "considers errors with different attributes unequal" do
      error1 = described_class.new(path: [:name], message: "invalid")
      error2 = described_class.new(path: [:email], message: "invalid")

      expect(error1).not_to eq(error2)
    end
  end
end

RSpec.describe Validrb::ErrorCollection do
  let(:error1) { Validrb::Error.new(path: [:name], message: "is required", code: :required) }
  let(:error2) { Validrb::Error.new(path: [:email], message: "is invalid", code: :format) }
  let(:error3) { Validrb::Error.new(path: [:user, :name], message: "too short", code: :min) }

  describe "#initialize" do
    it "creates an empty collection" do
      collection = described_class.new

      expect(collection).to be_empty
    end

    it "creates a collection with errors" do
      collection = described_class.new([error1, error2])

      expect(collection.size).to eq(2)
    end

    it "freezes the collection" do
      collection = described_class.new([error1])

      expect(collection).to be_frozen
    end
  end

  describe "Enumerable" do
    let(:collection) { described_class.new([error1, error2]) }

    it "is enumerable" do
      expect(collection).to be_a(Enumerable)
    end

    it "iterates over errors" do
      errors = []
      collection.each { |e| errors << e }

      expect(errors).to eq([error1, error2])
    end

    it "supports map" do
      messages = collection.map(&:message)

      expect(messages).to eq(["is required", "is invalid"])
    end
  end

  describe "#[]" do
    it "accesses errors by index" do
      collection = described_class.new([error1, error2])

      expect(collection[0]).to eq(error1)
      expect(collection[1]).to eq(error2)
    end
  end

  describe "#add" do
    it "returns new collection with added error" do
      collection = described_class.new([error1])
      new_collection = collection.add(error2)

      expect(collection.size).to eq(1)
      expect(new_collection.size).to eq(2)
      expect(new_collection[1]).to eq(error2)
    end
  end

  describe "#merge" do
    it "returns new collection with merged errors" do
      collection1 = described_class.new([error1])
      collection2 = described_class.new([error2])
      merged = collection1.merge(collection2)

      expect(merged.size).to eq(2)
      expect(merged.to_a).to eq([error1, error2])
    end
  end

  describe "#for_path" do
    it "filters errors by path prefix" do
      collection = described_class.new([error1, error2, error3])
      user_errors = collection.for_path(:user)

      expect(user_errors.size).to eq(1)
      expect(user_errors[0]).to eq(error3)
    end
  end

  describe "#messages" do
    it "returns array of messages" do
      collection = described_class.new([error1, error2])

      expect(collection.messages).to eq(["is required", "is invalid"])
    end
  end

  describe "#full_messages" do
    it "returns array of full messages with paths" do
      collection = described_class.new([error1, error2])

      expect(collection.full_messages).to eq(["name: is required", "email: is invalid"])
    end
  end

  describe "#to_h" do
    it "groups errors by path" do
      another_name_error = Validrb::Error.new(path: [:name], message: "too long")
      collection = described_class.new([error1, another_name_error, error2])

      expect(collection.to_h).to eq({
                                      "name" => ["is required", "too long"],
                                      "email" => ["is invalid"]
                                    })
    end
  end
end

RSpec.describe Validrb::ValidationError do
  let(:error) { Validrb::Error.new(path: [:name], message: "is required") }

  describe "#initialize" do
    it "creates exception with error collection" do
      collection = Validrb::ErrorCollection.new([error])
      exception = described_class.new(collection)

      expect(exception.errors).to be_a(Validrb::ErrorCollection)
      expect(exception.errors.size).to eq(1)
    end

    it "wraps array of errors in collection" do
      exception = described_class.new([error])

      expect(exception.errors).to be_a(Validrb::ErrorCollection)
    end
  end

  describe "#message" do
    it "includes validation error messages" do
      error2 = Validrb::Error.new(path: [:email], message: "is invalid")
      exception = described_class.new([error, error2])

      expect(exception.message).to include("Validation failed")
      expect(exception.message).to include("name: is required")
      expect(exception.message).to include("email: is invalid")
    end

    it "handles empty errors" do
      exception = described_class.new([])

      expect(exception.message).to eq("Validation failed")
    end
  end
end
