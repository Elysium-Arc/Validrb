# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Constraints::Format do
  describe "with regex" do
    let(:constraint) { described_class.new(/\A[A-Z]+\z/) }

    it "passes for matching strings" do
      expect(constraint.valid?("HELLO")).to be true
      expect(constraint.valid?("ABC")).to be true
    end

    it "fails for non-matching strings" do
      expect(constraint.valid?("hello")).to be false
      expect(constraint.valid?("Hello")).to be false
      expect(constraint.valid?("123")).to be false
    end

    it "fails for non-strings" do
      expect(constraint.valid?(123)).to be false
      expect(constraint.valid?(nil)).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("hello")).to include("must match format")
    end
  end

  describe "with :email format" do
    let(:constraint) { described_class.new(:email) }

    it "passes for valid emails" do
      expect(constraint.valid?("user@example.com")).to be true
      expect(constraint.valid?("user.name@example.co.uk")).to be true
      expect(constraint.valid?("user+tag@example.com")).to be true
    end

    it "fails for invalid emails" do
      expect(constraint.valid?("not-an-email")).to be false
      expect(constraint.valid?("@example.com")).to be false
      expect(constraint.valid?("user@")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("invalid")).to eq("must be a valid email")
    end
  end

  describe "with :url format" do
    let(:constraint) { described_class.new(:url) }

    it "passes for valid URLs" do
      expect(constraint.valid?("http://example.com")).to be true
      expect(constraint.valid?("https://example.com/path")).to be true
      expect(constraint.valid?("https://example.com/path?query=1")).to be true
    end

    it "fails for invalid URLs" do
      expect(constraint.valid?("not-a-url")).to be false
      expect(constraint.valid?("ftp://example.com")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("invalid")).to eq("must be a valid url")
    end
  end

  describe "with :uuid format" do
    let(:constraint) { described_class.new(:uuid) }

    it "passes for valid UUIDs" do
      expect(constraint.valid?("550e8400-e29b-41d4-a716-446655440000")).to be true
      expect(constraint.valid?("550E8400-E29B-41D4-A716-446655440000")).to be true
    end

    it "fails for invalid UUIDs" do
      expect(constraint.valid?("not-a-uuid")).to be false
      expect(constraint.valid?("550e8400-e29b-41d4-a716")).to be false
    end

    it "returns appropriate error message" do
      expect(constraint.error_message("invalid")).to eq("must be a valid uuid")
    end
  end

  describe "with :phone format" do
    let(:constraint) { described_class.new(:phone) }

    it "passes for valid phone numbers" do
      expect(constraint.valid?("+1-555-555-5555")).to be true
      expect(constraint.valid?("555-555-5555")).to be true
      expect(constraint.valid?("(555) 555-5555")).to be true
    end

    it "fails for invalid phone numbers" do
      expect(constraint.valid?("123")).to be false
      expect(constraint.valid?("not-a-phone")).to be false
    end
  end

  describe "with :alphanumeric format" do
    let(:constraint) { described_class.new(:alphanumeric) }

    it "passes for alphanumeric strings" do
      expect(constraint.valid?("abc123")).to be true
      expect(constraint.valid?("ABC")).to be true
    end

    it "fails for non-alphanumeric strings" do
      expect(constraint.valid?("abc-123")).to be false
      expect(constraint.valid?("hello world")).to be false
    end
  end

  describe "with :slug format" do
    let(:constraint) { described_class.new(:slug) }

    it "passes for valid slugs" do
      expect(constraint.valid?("hello-world")).to be true
      expect(constraint.valid?("test123")).to be true
    end

    it "fails for invalid slugs" do
      expect(constraint.valid?("Hello-World")).to be false
      expect(constraint.valid?("hello--world")).to be false
    end
  end

  describe "with unknown format" do
    it "raises ArgumentError" do
      expect do
        described_class.new(:unknown_format)
      end.to raise_error(ArgumentError, /Unknown format/)
    end
  end

  describe "with invalid pattern type" do
    it "raises ArgumentError" do
      expect do
        described_class.new(123)
      end.to raise_error(ArgumentError, /must be a Regexp or Symbol/)
    end
  end

  describe "#call" do
    let(:constraint) { described_class.new(:email) }

    it "returns empty array for valid value" do
      errors = constraint.call("user@example.com")

      expect(errors).to be_empty
    end

    it "returns error for invalid value" do
      errors = constraint.call("invalid")

      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:format)
    end
  end

  describe "registry" do
    it "is registered as :format" do
      expect(Validrb::Constraints.lookup(:format)).to eq(described_class)
    end
  end
end
