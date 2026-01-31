# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::I18n do
  before do
    described_class.reset!
  end

  after do
    described_class.reset!
  end

  describe ".locale" do
    it "defaults to :en" do
      expect(described_class.locale).to eq(:en)
    end

    it "can be changed" do
      described_class.locale = :fr
      expect(described_class.locale).to eq(:fr)
    end
  end

  describe ".t" do
    it "translates known keys" do
      expect(described_class.t(:required)).to eq("is required")
    end

    it "returns key as string for unknown keys" do
      expect(described_class.t(:unknown_key_here)).to eq("unknown_key_here")
    end

    it "interpolates values" do
      expect(described_class.t(:min, value: 5)).to eq("must be at least 5")
    end

    it "interpolates multiple values" do
      expect(described_class.t(:min_length, value: 3, actual: 1)).to eq("length must be at least 3 (got 1)")
    end
  end

  describe ".add_translations" do
    it "adds custom translations" do
      described_class.add_translations(:en, custom: "custom message")
      expect(described_class.t(:custom)).to eq("custom message")
    end

    it "overrides default translations" do
      described_class.add_translations(:en, required: "this field is required")
      expect(described_class.t(:required)).to eq("this field is required")
    end

    it "adds translations for other locales" do
      described_class.add_translations(:fr, required: "est requis")
      described_class.locale = :fr
      expect(described_class.t(:required)).to eq("est requis")
    end
  end

  describe ".configure" do
    it "yields self for configuration" do
      described_class.configure do |config|
        config.locale = :de
      end
      expect(described_class.locale).to eq(:de)
    end
  end

  describe ".reset!" do
    it "resets locale to default" do
      described_class.locale = :fr
      described_class.reset!
      expect(described_class.locale).to eq(:en)
    end

    it "resets translations to defaults" do
      described_class.add_translations(:en, required: "custom")
      described_class.reset!
      expect(described_class.t(:required)).to eq("is required")
    end
  end

  describe "fallback to English" do
    it "falls back to English for missing locale translations" do
      described_class.locale = :xx  # Non-existent locale
      expect(described_class.t(:required)).to eq("is required")
    end
  end
end
