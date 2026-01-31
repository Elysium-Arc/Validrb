# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Schema do
  describe "#initialize" do
    it "creates a schema with fields" do
      schema = described_class.new do
        field :name, :string
        field :age, :integer
      end

      expect(schema.fields.keys).to eq([:name, :age])
    end

    it "freezes the schema" do
      schema = described_class.new do
        field :name, :string
      end

      expect(schema).to be_frozen
      expect(schema.fields).to be_frozen
    end

    it "rejects duplicate fields" do
      expect do
        described_class.new do
          field :name, :string
          field :name, :integer
        end
      end.to raise_error(ArgumentError, /already defined/)
    end
  end

  describe "#parse" do
    let(:schema) do
      described_class.new do
        field :name, :string
        field :age, :integer
      end
    end

    it "returns validated data on success" do
      result = schema.parse({ name: "John", age: "30" })

      expect(result).to eq({ name: "John", age: 30 })
    end

    it "raises ValidationError on failure" do
      expect do
        schema.parse({ name: "John" })
      end.to raise_error(Validrb::ValidationError)
    end

    it "includes errors in exception" do
      begin
        schema.parse({ age: "invalid" })
      rescue Validrb::ValidationError => e
        expect(e.errors.size).to eq(2)
        expect(e.errors.map(&:path)).to include([:name], [:age])
      end
    end
  end

  describe "#safe_parse" do
    let(:schema) do
      described_class.new do
        field :name, :string
        field :age, :integer
      end
    end

    context "with valid data" do
      it "returns Success with data" do
        result = schema.safe_parse({ name: "John", age: 30 })

        expect(result).to be_a(Validrb::Success)
        expect(result.success?).to be true
        expect(result.data).to eq({ name: "John", age: 30 })
      end

      it "coerces string values" do
        result = schema.safe_parse({ name: "John", age: "30" })

        expect(result.data[:age]).to eq(30)
      end
    end

    context "with invalid data" do
      it "returns Failure with errors" do
        result = schema.safe_parse({ name: "John" })

        expect(result).to be_a(Validrb::Failure)
        expect(result.failure?).to be true
        expect(result.errors.size).to eq(1)
        expect(result.errors.first.path).to eq([:age])
      end

      it "collects all errors" do
        result = schema.safe_parse({})

        expect(result.errors.size).to eq(2)
      end
    end

    context "with string keys" do
      it "normalizes to symbol keys" do
        result = schema.safe_parse({ "name" => "John", "age" => 30 })

        expect(result.success?).to be true
        expect(result.data).to eq({ name: "John", age: 30 })
      end
    end

    context "with nil input" do
      it "treats as empty hash" do
        result = schema.safe_parse(nil)

        expect(result.failure?).to be true
        expect(result.errors.size).to eq(2)
      end
    end

    context "with non-hash input" do
      it "raises ArgumentError" do
        expect do
          schema.safe_parse("not a hash")
        end.to raise_error(ArgumentError, /Expected Hash/)
      end
    end

    context "with path_prefix" do
      it "prefixes error paths" do
        result = schema.safe_parse({}, path_prefix: [:user])

        expect(result.errors.first.path).to eq([:user, :name])
      end
    end
  end

  describe "DSL" do
    describe "#field" do
      it "defines a required field" do
        schema = described_class.new do
          field :name, :string
        end

        expect(schema.fields[:name].required?).to be true
      end

      it "accepts options" do
        schema = described_class.new do
          field :name, :string, min: 1, max: 100
        end

        expect(schema.fields[:name].constraints.size).to eq(2)
      end
    end

    describe "#optional" do
      it "defines an optional field" do
        schema = described_class.new do
          optional :nickname, :string
        end

        expect(schema.fields[:nickname].optional?).to be true
      end
    end

    describe "#required" do
      it "explicitly defines a required field" do
        schema = described_class.new do
          required :name, :string
        end

        expect(schema.fields[:name].required?).to be true
      end
    end
  end

  describe "optional fields" do
    let(:schema) do
      described_class.new do
        field :name, :string
        field :nickname, :string, optional: true
      end
    end

    it "excludes optional fields when missing" do
      result = schema.safe_parse({ name: "John" })

      expect(result.success?).to be true
      expect(result.data.key?(:nickname)).to be false
    end

    it "includes optional fields when present" do
      result = schema.safe_parse({ name: "John", nickname: "Johnny" })

      expect(result.data[:nickname]).to eq("Johnny")
    end
  end

  describe "default values" do
    let(:schema) do
      described_class.new do
        field :name, :string
        field :role, :string, default: "user"
      end
    end

    it "uses default when field is missing" do
      result = schema.safe_parse({ name: "John" })

      expect(result.success?).to be true
      expect(result.data[:role]).to eq("user")
    end

    it "overrides default when field is present" do
      result = schema.safe_parse({ name: "John", role: "admin" })

      expect(result.data[:role]).to eq("admin")
    end

    it "supports proc defaults" do
      counter = 0
      schema = described_class.new do
        field :id, :integer, default: -> { counter += 1 }
      end

      result1 = schema.safe_parse({})
      result2 = schema.safe_parse({})

      expect(result1.data[:id]).to eq(1)
      expect(result2.data[:id]).to eq(2)
    end
  end
end
