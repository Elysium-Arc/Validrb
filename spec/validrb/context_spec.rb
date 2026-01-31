# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Context do
  describe ".new" do
    it "creates a context with data" do
      context = described_class.new(user_id: 123, locale: :en)
      expect(context[:user_id]).to eq(123)
      expect(context[:locale]).to eq(:en)
    end

    it "freezes the context" do
      context = described_class.new(key: "value")
      expect(context).to be_frozen
    end
  end

  describe "#[]" do
    let(:context) { described_class.new(user_id: 123, admin: true) }

    it "accesses data by symbol key" do
      expect(context[:user_id]).to eq(123)
    end

    it "accesses data by string key (converts to symbol)" do
      expect(context["admin"]).to be true
    end

    it "returns nil for missing keys" do
      expect(context[:unknown]).to be_nil
    end
  end

  describe "#key?" do
    let(:context) { described_class.new(user_id: 123) }

    it "returns true for existing keys" do
      expect(context.key?(:user_id)).to be true
    end

    it "returns false for missing keys" do
      expect(context.key?(:unknown)).to be false
    end
  end

  describe "#fetch" do
    let(:context) { described_class.new(user_id: 123) }

    it "returns value for existing key" do
      expect(context.fetch(:user_id)).to eq(123)
    end

    it "returns default for missing key" do
      expect(context.fetch(:unknown, "default")).to eq("default")
    end

    it "calls block for missing key" do
      expect(context.fetch(:unknown) { "block" }).to eq("block")
    end
  end

  describe "#to_h" do
    it "returns a copy of the data" do
      context = described_class.new(a: 1, b: 2)
      hash = context.to_h
      expect(hash).to eq({ a: 1, b: 2 })
      expect(hash).not_to be(context.data)
    end
  end

  describe "#empty?" do
    it "returns true for empty context" do
      expect(described_class.empty.empty?).to be true
    end

    it "returns false for non-empty context" do
      expect(described_class.new(a: 1).empty?).to be false
    end
  end

  describe ".empty" do
    it "returns the empty context singleton" do
      expect(described_class.empty).to be(Validrb::Context::EMPTY)
    end
  end
end
