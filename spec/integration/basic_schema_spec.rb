# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Basic Schema Integration" do
  describe "simple user schema" do
    let(:schema) do
      Validrb.schema do
        field :name, :string, min: 1, max: 100
        field :email, :string, format: :email
        field :age, :integer, min: 0, optional: true
        field :role, :string, enum: %w[admin user guest], default: "user"
      end
    end

    it "validates correct data" do
      result = schema.safe_parse({
                                   name: "John Doe",
                                   email: "john@example.com"
                                 })

      expect(result.success?).to be true
      expect(result.data).to eq({
                                  name: "John Doe",
                                  email: "john@example.com",
                                  role: "user"
                                })
    end

    it "coerces string values" do
      result = schema.safe_parse({
                                   name: "John",
                                   email: "john@example.com",
                                   age: "30"
                                 })

      expect(result.success?).to be true
      expect(result.data[:age]).to eq(30)
    end

    it "validates constraints" do
      result = schema.safe_parse({
                                   name: "",
                                   email: "john@example.com"
                                 })

      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:min)
    end

    it "validates format" do
      result = schema.safe_parse({
                                   name: "John",
                                   email: "not-an-email"
                                 })

      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:format)
    end

    it "validates enum" do
      result = schema.safe_parse({
                                   name: "John",
                                   email: "john@example.com",
                                   role: "superadmin"
                                 })

      expect(result.failure?).to be true
      expect(result.errors.first.code).to eq(:enum)
    end

    it "collects all validation errors" do
      result = schema.safe_parse({
                                   name: "",
                                   email: "invalid",
                                   role: "superadmin"
                                 })

      expect(result.failure?).to be true
      expect(result.errors.size).to eq(3)
    end
  end

  describe "parse vs safe_parse" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
      end
    end

    it "parse returns data on success" do
      data = schema.parse({ name: "John" })

      expect(data).to eq({ name: "John" })
    end

    it "parse raises on failure" do
      expect do
        schema.parse({})
      end.to raise_error(Validrb::ValidationError)
    end

    it "safe_parse returns Result on success" do
      result = schema.safe_parse({ name: "John" })

      expect(result).to be_a(Validrb::Success)
    end

    it "safe_parse returns Result on failure" do
      result = schema.safe_parse({})

      expect(result).to be_a(Validrb::Failure)
    end
  end

  describe "type coercion examples" do
    let(:schema) do
      Validrb.schema do
        field :count, :integer
        field :price, :float
        field :active, :boolean
        field :name, :string
      end
    end

    it "coerces various types" do
      result = schema.safe_parse({
                                   count: "42",
                                   price: "19.99",
                                   active: "true",
                                   name: :john
                                 })

      expect(result.success?).to be true
      expect(result.data).to eq({
                                  count: 42,
                                  price: 19.99,
                                  active: true,
                                  name: "john"
                                })
    end

    it "handles integer from float" do
      result = schema.safe_parse({
                                   count: 42.0,
                                   price: 19,
                                   active: 1,
                                   name: 123
                                 })

      expect(result.success?).to be true
      expect(result.data[:count]).to eq(42)
      expect(result.data[:price]).to eq(19.0)
      expect(result.data[:active]).to be true
      expect(result.data[:name]).to eq("123")
    end
  end

  describe "array field" do
    let(:schema) do
      Validrb.schema do
        field :tags, :array, of: :string
        field :scores, :array, of: :integer
      end
    end

    it "validates array items" do
      result = schema.safe_parse({
                                   tags: [:ruby, :rails],
                                   scores: ["100", "95", "87"]
                                 })

      expect(result.success?).to be true
      expect(result.data[:tags]).to eq(%w[ruby rails])
      expect(result.data[:scores]).to eq([100, 95, 87])
    end

    it "reports item validation errors" do
      result = schema.safe_parse({
                                   tags: ["valid", 123],
                                   scores: ["100", "invalid"]
                                 })

      expect(result.failure?).to be true
      expect(result.errors.any? { |e| e.path == [:scores, 1] }).to be true
    end
  end

  describe "string/symbol key handling" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
        field :age, :integer
      end
    end

    it "accepts symbol keys" do
      result = schema.safe_parse({ name: "John", age: 30 })

      expect(result.success?).to be true
    end

    it "accepts string keys" do
      result = schema.safe_parse({ "name" => "John", "age" => 30 })

      expect(result.success?).to be true
    end

    it "normalizes to symbol keys in output" do
      result = schema.safe_parse({ "name" => "John", "age" => 30 })

      expect(result.data.keys).to all(be_a(Symbol))
    end
  end

  describe "error path tracking" do
    let(:schema) do
      Validrb.schema do
        field :user, :string
        field :items, :array, of: :integer
      end
    end

    it "tracks field paths" do
      result = schema.safe_parse({ items: [1, 2, 3] })

      expect(result.errors.first.path).to eq([:user])
    end

    it "tracks array item paths" do
      result = schema.safe_parse({
                                   user: "john",
                                   items: ["1", "invalid", "3"]
                                 })

      expect(result.errors.first.path).to eq([:items, 1])
    end
  end
end
