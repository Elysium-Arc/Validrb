# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Phase 2 Features Integration" do
  describe "custom validators" do
    it "validates with custom block" do
      schema = Validrb.schema do
        field :password, :string
        field :password_confirmation, :string

        validate do |data|
          if data[:password] != data[:password_confirmation]
            error(:password_confirmation, "doesn't match password")
          end
        end
      end

      result = schema.safe_parse({
                                   password: "secret123",
                                   password_confirmation: "secret123"
                                 })
      expect(result.success?).to be true

      result = schema.safe_parse({
                                   password: "secret123",
                                   password_confirmation: "different"
                                 })
      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:password_confirmation])
      expect(result.errors.first.message).to eq("doesn't match password")
    end

    it "supports multiple validators" do
      schema = Validrb.schema do
        field :start_date, :date
        field :end_date, :date

        validate do |data|
          if data[:end_date] < data[:start_date]
            error(:end_date, "must be after start date")
          end
        end

        validate do |data|
          if data[:start_date] < Date.today
            error(:start_date, "cannot be in the past")
          end
        end
      end

      result = schema.safe_parse({
                                   start_date: Date.today + 10,
                                   end_date: Date.today + 5
                                 })
      expect(result.failure?).to be true
      expect(result.errors.first.message).to eq("must be after start date")
    end

    it "supports base_error for non-field errors" do
      schema = Validrb.schema do
        field :items, :array, of: :string

        validate do |data|
          base_error("at least one item is required") if data[:items].empty?
        end
      end

      result = schema.safe_parse({ items: [] })
      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([])
    end

    it "can access data via bracket notation" do
      schema = Validrb.schema do
        field :min, :integer
        field :max, :integer

        validate do
          error(:max, "must be greater than min") if self[:max] <= self[:min]
        end
      end

      result = schema.safe_parse({ min: 10, max: 5 })
      expect(result.failure?).to be true
    end

    it "skips validators when field validation fails" do
      validator_called = false

      schema = Validrb.schema do
        field :name, :string, min: 1

        validate do
          validator_called = true
        end
      end

      schema.safe_parse({ name: "" })
      expect(validator_called).to be false
    end
  end

  describe "custom error messages" do
    it "uses custom message for field" do
      schema = Validrb.schema do
        field :age, :integer, min: 18, message: "You must be 18 or older"
      end

      result = schema.safe_parse({ age: 15 })
      expect(result.errors.first.message).to eq("You must be 18 or older")
    end

    it "uses custom message for required field" do
      schema = Validrb.schema do
        field :name, :string, message: "Name is required"
      end

      result = schema.safe_parse({})
      expect(result.errors.first.message).to eq("Name is required")
    end

    it "uses custom message for type errors" do
      schema = Validrb.schema do
        field :count, :integer, message: "Must be a valid number"
      end

      result = schema.safe_parse({ count: "abc" })
      expect(result.errors.first.message).to eq("Must be a valid number")
    end
  end

  describe "transforms" do
    it "transforms value after validation" do
      schema = Validrb.schema do
        field :email, :string, transform: ->(v) { v.downcase.strip }
      end

      result = schema.safe_parse({ email: "  USER@EXAMPLE.COM  " })
      expect(result.data[:email]).to eq("user@example.com")
    end

    it "transforms default values" do
      schema = Validrb.schema do
        field :slug, :string, default: "New Post", transform: ->(v) { v.downcase.gsub(" ", "-") }
      end

      result = schema.safe_parse({})
      expect(result.data[:slug]).to eq("new-post")
    end

    it "can transform to different type" do
      schema = Validrb.schema do
        field :tags, :string, transform: ->(v) { v.split(",").map(&:strip) }
      end

      result = schema.safe_parse({ tags: "ruby, rails, api" })
      expect(result.data[:tags]).to eq(%w[ruby rails api])
    end
  end

  describe "nullable fields" do
    it "allows nil for nullable fields" do
      schema = Validrb.schema do
        field :nickname, :string, nullable: true
      end

      result = schema.safe_parse({ nickname: nil })
      expect(result.success?).to be true
      expect(result.data[:nickname]).to be_nil
    end

    it "still validates non-nil values for nullable fields" do
      schema = Validrb.schema do
        field :age, :integer, nullable: true, min: 0
      end

      result = schema.safe_parse({ age: nil })
      expect(result.success?).to be true

      result = schema.safe_parse({ age: -5 })
      expect(result.failure?).to be true
    end

    it "distinguishes nullable from optional" do
      schema = Validrb.schema do
        field :required_nullable, :string, nullable: true
        field :optional_not_nullable, :string, optional: true
      end

      # Missing required_nullable should fail
      result = schema.safe_parse({})
      expect(result.failure?).to be true

      # Explicit nil for required_nullable should pass
      result = schema.safe_parse({ required_nullable: nil })
      expect(result.success?).to be true
    end
  end

  describe "strict mode" do
    it "rejects unknown keys in strict mode" do
      schema = Validrb.schema(strict: true) do
        field :name, :string
      end

      result = schema.safe_parse({ name: "John", extra: "value" })
      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:extra])
      expect(result.errors.first.code).to eq(:unknown_key)
    end

    it "allows known keys in strict mode" do
      schema = Validrb.schema(strict: true) do
        field :name, :string
        field :age, :integer
      end

      result = schema.safe_parse({ name: "John", age: 30 })
      expect(result.success?).to be true
    end
  end

  describe "passthrough mode" do
    it "includes unknown keys in output" do
      schema = Validrb.schema(passthrough: true) do
        field :name, :string
      end

      result = schema.safe_parse({ name: "John", extra: "value", another: 123 })
      expect(result.success?).to be true
      expect(result.data[:name]).to eq("John")
      expect(result.data[:extra]).to eq("value")
      expect(result.data[:another]).to eq(123)
    end

    it "strips unknown keys by default" do
      schema = Validrb.schema do
        field :name, :string
      end

      result = schema.safe_parse({ name: "John", extra: "value" })
      expect(result.success?).to be true
      expect(result.data.keys).to eq([:name])
    end
  end

  describe "schema composition" do
    describe "#extend" do
      it "creates new schema with additional fields" do
        base = Validrb.schema do
          field :id, :integer
        end

        extended = base.extend do
          field :name, :string
        end

        result = extended.safe_parse({ id: 1, name: "John" })
        expect(result.success?).to be true
        expect(result.data).to eq({ id: 1, name: "John" })
      end

      it "preserves parent validators" do
        base = Validrb.schema do
          field :value, :integer

          validate do |data|
            error(:value, "must be positive") if data[:value] <= 0
          end
        end

        extended = base.extend do
          field :name, :string
        end

        result = extended.safe_parse({ value: -1, name: "test" })
        expect(result.failure?).to be true
      end
    end

    describe "#pick" do
      it "creates schema with only specified fields" do
        full = Validrb.schema do
          field :id, :integer
          field :name, :string
          field :email, :string
          field :age, :integer
        end

        picked = full.pick(:id, :name)

        result = picked.safe_parse({ id: 1, name: "John" })
        expect(result.success?).to be true
        expect(picked.fields.keys).to eq(%i[id name])
      end
    end

    describe "#omit" do
      it "creates schema without specified fields" do
        full = Validrb.schema do
          field :id, :integer
          field :name, :string
          field :password, :string
        end

        public_schema = full.omit(:password)

        expect(public_schema.fields.keys).to eq(%i[id name])
      end
    end

    describe "#merge" do
      it "merges two schemas" do
        schema1 = Validrb.schema do
          field :name, :string
          field :age, :integer
        end

        schema2 = Validrb.schema do
          field :email, :string
          field :age, :string # Override type
        end

        merged = schema1.merge(schema2)

        expect(merged.fields.keys).to contain_exactly(:name, :age, :email)
        # schema2's age field should take precedence
        expect(merged.fields[:age].type).to be_a(Validrb::Types::String)
      end
    end

    describe "#partial" do
      it "makes all fields optional" do
        schema = Validrb.schema do
          field :name, :string
          field :email, :string
        end

        partial = schema.partial

        result = partial.safe_parse({})
        expect(result.success?).to be true

        result = partial.safe_parse({ name: "John" })
        expect(result.success?).to be true
      end
    end
  end

  describe "date/time types" do
    it "validates date fields" do
      schema = Validrb.schema do
        field :birth_date, :date
      end

      result = schema.safe_parse({ birth_date: "1990-05-15" })
      expect(result.success?).to be true
      expect(result.data[:birth_date]).to eq(Date.new(1990, 5, 15))
    end

    it "validates datetime fields" do
      schema = Validrb.schema do
        field :created_at, :datetime
      end

      result = schema.safe_parse({ created_at: "2024-01-15T12:30:00Z" })
      expect(result.success?).to be true
      expect(result.data[:created_at]).to be_a(DateTime)
    end

    it "validates time fields" do
      schema = Validrb.schema do
        field :timestamp, :time
      end

      result = schema.safe_parse({ timestamp: 1705320600 })
      expect(result.success?).to be true
      expect(result.data[:timestamp]).to be_a(Time)
    end
  end

  describe "decimal type" do
    it "validates decimal fields" do
      schema = Validrb.schema do
        field :price, :decimal
        field :quantity, :integer
      end

      result = schema.safe_parse({ price: "19.99", quantity: 5 })
      expect(result.success?).to be true
      expect(result.data[:price]).to be_a(BigDecimal)
      expect(result.data[:price]).to eq(BigDecimal("19.99"))
    end

    it "maintains precision" do
      schema = Validrb.schema do
        field :amount, :decimal
      end

      result = schema.safe_parse({ amount: "0.1" })
      # This is where BigDecimal shines vs Float
      ten_times = result.data[:amount] * 10
      expect(ten_times).to eq(BigDecimal("1"))
    end
  end
end
