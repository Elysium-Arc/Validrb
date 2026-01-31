# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe Validrb::Rails::ErrorConverter do
  describe ".to_hash" do
    it "converts single error to hash" do
      errors = [Validrb::Error.new(path: [:name], message: "is required", code: :required)]
      result = described_class.to_hash(errors)

      expect(result).to eq({ name: ["is required"] })
    end

    it "groups multiple errors for same attribute" do
      errors = [
        Validrb::Error.new(path: [:password], message: "is too short", code: :min),
        Validrb::Error.new(path: [:password], message: "must contain digit", code: :refinement)
      ]
      result = described_class.to_hash(errors)

      expect(result[:password]).to contain_exactly("is too short", "must contain digit")
    end

    it "handles nested paths" do
      errors = [Validrb::Error.new(path: [:user, :address, :city], message: "is required", code: :required)]
      result = described_class.to_hash(errors)

      expect(result[:"user.address.city"]).to eq(["is required"])
    end

    it "handles empty path as base" do
      errors = [Validrb::Error.new(path: [], message: "is invalid", code: :custom)]
      result = described_class.to_hash(errors)

      expect(result[:base]).to eq(["is invalid"])
    end

    it "handles ErrorCollection" do
      errors = Validrb::ErrorCollection.new([
        Validrb::Error.new(path: [:name], message: "is required", code: :required)
      ])
      result = described_class.to_hash(errors)

      expect(result[:name]).to eq(["is required"])
    end
  end

  describe ".add_to_active_model" do
    let(:model_class) do
      Class.new do
        include ActiveModel::Model
        attr_accessor :name, :email
      end
    end

    let(:model) { model_class.new }

    it "adds errors to ActiveModel::Errors" do
      validrb_errors = [
        Validrb::Error.new(path: [:name], message: "is required", code: :required),
        Validrb::Error.new(path: [:email], message: "is invalid", code: :format)
      ]

      described_class.add_to_active_model(validrb_errors, model.errors)

      expect(model.errors[:name]).to include("is required")
      expect(model.errors[:email]).to include("is invalid")
    end
  end

  describe ".error_attribute" do
    it "returns :base for empty path" do
      expect(described_class.error_attribute([])).to eq(:base)
    end

    it "returns symbol for single element" do
      expect(described_class.error_attribute([:name])).to eq(:name)
    end

    it "joins nested path with dots" do
      expect(described_class.error_attribute([:user, :address, :city])).to eq(:"user.address.city")
    end

    it "handles array indices in path" do
      expect(described_class.error_attribute([:items, 0, :name])).to eq(:"items.0.name")
    end
  end
end
