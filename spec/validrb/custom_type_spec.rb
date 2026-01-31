# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::CustomType do
  after do
    # Clean up registered types
    Validrb::Types.registry.delete(:test_email)
    Validrb::Types.registry.delete(:positive_int)
    Validrb::Types.registry.delete(:uppercase)
  end

  describe ".define" do
    it "creates and registers a custom type" do
      Validrb.define_type(:test_email) do
        coerce { |v| v.to_s.strip.downcase }
        validate { |v| v.include?("@") }
        error_message { "must be a valid email" }
      end

      expect(Validrb::Types.lookup(:test_email)).not_to be_nil
    end

    it "allows using the custom type in schemas" do
      Validrb.define_type(:positive_int) do
        coerce { |v| Integer(v) }
        validate { |v| v > 0 }
        error_message { |v| "must be positive, got #{v}" }
      end

      schema = Validrb.schema do
        field :count, :positive_int
      end

      result = schema.safe_parse({ count: "42" })
      expect(result.success?).to be true
      expect(result.data[:count]).to eq(42)

      result = schema.safe_parse({ count: "-5" })
      expect(result.failure?).to be true
    end

    it "supports coerce-only types" do
      Validrb.define_type(:uppercase) do
        coerce { |v| v.to_s.upcase }
      end

      schema = Validrb.schema do
        field :name, :uppercase
      end

      result = schema.safe_parse({ name: "hello" })
      expect(result.success?).to be true
      expect(result.data[:name]).to eq("HELLO")
    end

    it "handles coercion errors gracefully" do
      Validrb.define_type(:positive_int) do
        coerce { |v| Integer(v) }
        validate { |v| v > 0 }
      end

      schema = Validrb.schema do
        field :count, :positive_int
      end

      result = schema.safe_parse({ count: "not a number" })
      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:type_error)
    end
  end
end
