# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Schema Introspection" do
  let(:schema) do
    Validrb.schema do
      field :id, :integer
      field :name, :string, min: 1, max: 100
      field :email, :string, format: :email
      field :age, :integer, optional: true, min: 0
      field :status, :string, enum: %w[active inactive], default: "active"
      field :is_admin, :boolean, when: ->(d) { d[:role] == "admin" }
    end
  end

  describe "#field_names" do
    it "returns all field names" do
      expect(schema.field_names).to eq([:id, :name, :email, :age, :status, :is_admin])
    end
  end

  describe "#field" do
    it "returns field by name" do
      field = schema.field(:name)
      expect(field).to be_a(Validrb::Field)
      expect(field.name).to eq(:name)
    end

    it "returns nil for unknown fields" do
      expect(schema.field(:unknown)).to be_nil
    end
  end

  describe "#field?" do
    it "returns true for existing fields" do
      expect(schema.field?(:name)).to be true
    end

    it "returns false for missing fields" do
      expect(schema.field?(:unknown)).to be false
    end
  end

  describe "#required_fields" do
    it "returns non-optional, non-conditional fields" do
      expect(schema.required_fields).to eq([:id, :name, :email])
    end
  end

  describe "#optional_fields" do
    it "returns optional fields" do
      expect(schema.optional_fields).to eq([:age])
    end
  end

  describe "#conditional_fields" do
    it "returns conditional fields" do
      expect(schema.conditional_fields).to eq([:is_admin])
    end
  end

  describe "#fields_with_defaults" do
    it "returns fields with defaults" do
      expect(schema.fields_with_defaults).to eq([:status])
    end
  end

  describe "#to_schema_hash" do
    it "returns schema structure as hash" do
      hash = schema.to_schema_hash

      expect(hash[:fields]).to be_a(Hash)
      expect(hash[:fields][:name][:type]).to eq("string")
      expect(hash[:fields][:name][:optional]).to be false
      expect(hash[:options]).to include(:strict, :passthrough)
    end
  end

  describe "#to_json_schema" do
    it "generates JSON Schema" do
      json_schema = schema.to_json_schema

      expect(json_schema["$schema"]).to eq("https://json-schema.org/draft-07/schema#")
      expect(json_schema["type"]).to eq("object")
      expect(json_schema["required"]).to include("id", "name", "email")
    end

    it "maps types correctly" do
      json_schema = schema.to_json_schema
      props = json_schema["properties"]

      expect(props["id"]["type"]).to eq("integer")
      expect(props["name"]["type"]).to eq("string")
    end

    it "includes constraints" do
      json_schema = schema.to_json_schema
      name_prop = json_schema["properties"]["name"]

      expect(name_prop["minLength"]).to eq(1)
      expect(name_prop["maxLength"]).to eq(100)
    end

    it "includes enum values" do
      json_schema = schema.to_json_schema
      status_prop = json_schema["properties"]["status"]

      expect(status_prop["enum"]).to eq(%w[active inactive])
    end

    it "includes defaults" do
      json_schema = schema.to_json_schema
      status_prop = json_schema["properties"]["status"]

      expect(status_prop["default"]).to eq("active")
    end
  end
end

RSpec.describe "Field Introspection" do
  let(:field) do
    Validrb::Field.new(:name, :string, min: 1, max: 100, format: :email)
  end

  describe "#constraint" do
    it "returns constraint by type" do
      min = field.constraint(Validrb::Constraints::Min)
      expect(min).to be_a(Validrb::Constraints::Min)
      expect(min.value).to eq(1)
    end

    it "returns nil for missing constraint" do
      enum = field.constraint(Validrb::Constraints::Enum)
      expect(enum).to be_nil
    end
  end

  describe "#has_constraint?" do
    it "returns true for existing constraints" do
      expect(field.has_constraint?(Validrb::Constraints::Min)).to be true
      expect(field.has_constraint?(Validrb::Constraints::Format)).to be true
    end

    it "returns false for missing constraints" do
      expect(field.has_constraint?(Validrb::Constraints::Enum)).to be false
    end
  end

  describe "#constraint_values" do
    it "returns all constraint values as hash" do
      values = field.constraint_values
      expect(values[:min]).to eq(1)
      expect(values[:max]).to eq(100)
      expect(values[:format]).to be_a(Regexp)
    end
  end
end
