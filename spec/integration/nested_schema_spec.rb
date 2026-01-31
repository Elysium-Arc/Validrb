# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Nested Schema Integration" do
  describe "nested object schema" do
    let(:address_schema) do
      Validrb.schema do
        field :street, :string
        field :city, :string
        field :zip, :string, format: /\A\d{5}\z/
      end
    end

    let(:user_schema) do
      address = address_schema
      Validrb.schema do
        field :name, :string
        field :address, :object, schema: address
      end
    end

    it "validates nested objects" do
      result = user_schema.safe_parse({
                                        name: "John",
                                        address: {
                                          street: "123 Main St",
                                          city: "Boston",
                                          zip: "02101"
                                        }
                                      })

      expect(result.success?).to be true
      expect(result.data[:address]).to eq({
                                            street: "123 Main St",
                                            city: "Boston",
                                            zip: "02101"
                                          })
    end

    it "reports nested validation errors with full path" do
      result = user_schema.safe_parse({
                                        name: "John",
                                        address: {
                                          street: "123 Main St",
                                          city: "Boston",
                                          zip: "invalid"
                                        }
                                      })

      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:address, :zip])
    end

    it "reports missing nested fields" do
      result = user_schema.safe_parse({
                                        name: "John",
                                        address: {
                                          street: "123 Main St"
                                        }
                                      })

      expect(result.failure?).to be true
      error_paths = result.errors.map(&:path)
      expect(error_paths).to include([:address, :city])
      expect(error_paths).to include([:address, :zip])
    end

    it "reports error when nested object is missing" do
      result = user_schema.safe_parse({ name: "John" })

      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:address])
    end
  end

  describe "deeply nested schemas" do
    let(:inner_schema) do
      Validrb.schema do
        field :value, :integer, min: 0
      end
    end

    let(:middle_schema) do
      inner = inner_schema
      Validrb.schema do
        field :inner, :object, schema: inner
      end
    end

    let(:outer_schema) do
      middle = middle_schema
      Validrb.schema do
        field :middle, :object, schema: middle
      end
    end

    it "validates deeply nested data" do
      result = outer_schema.safe_parse({
                                         middle: {
                                           inner: {
                                             value: 42
                                           }
                                         }
                                       })

      expect(result.success?).to be true
    end

    it "tracks deep paths in errors" do
      result = outer_schema.safe_parse({
                                         middle: {
                                           inner: {
                                             value: -1
                                           }
                                         }
                                       })

      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:middle, :inner, :value])
    end
  end

  describe "array of objects" do
    let(:item_schema) do
      Validrb.schema do
        field :name, :string
        field :quantity, :integer, min: 1
      end
    end

    let(:order_schema) do
      item = item_schema
      Validrb.schema do
        field :order_id, :string
        field :items, :array, of: Validrb::Types::Object.new(schema: item)
      end
    end

    it "validates array of nested objects" do
      result = order_schema.safe_parse({
                                         order_id: "ORD-001",
                                         items: [
                                           { name: "Widget", quantity: 2 },
                                           { name: "Gadget", quantity: 1 }
                                         ]
                                       })

      expect(result.success?).to be true
      expect(result.data[:items].size).to eq(2)
    end

    it "reports errors with array index and field path" do
      result = order_schema.safe_parse({
                                         order_id: "ORD-001",
                                         items: [
                                           { name: "Widget", quantity: 2 },
                                           { name: "Gadget", quantity: 0 }
                                         ]
                                       })

      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:items, 1, :quantity])
    end
  end

  describe "optional nested objects" do
    let(:profile_schema) do
      Validrb.schema do
        field :bio, :string
        field :website, :string, format: :url
      end
    end

    let(:user_schema) do
      profile = profile_schema
      Validrb.schema do
        field :name, :string
        field :profile, :object, schema: profile, optional: true
      end
    end

    it "allows missing optional nested object" do
      result = user_schema.safe_parse({ name: "John" })

      expect(result.success?).to be true
      expect(result.data.key?(:profile)).to be false
    end

    it "validates optional nested object when present" do
      result = user_schema.safe_parse({
                                        name: "John",
                                        profile: {
                                          bio: "Developer",
                                          website: "https://example.com"
                                        }
                                      })

      expect(result.success?).to be true
      expect(result.data[:profile]).to eq({
                                            bio: "Developer",
                                            website: "https://example.com"
                                          })
    end

    it "validates optional nested object fields when present" do
      result = user_schema.safe_parse({
                                        name: "John",
                                        profile: {
                                          bio: "Developer",
                                          website: "not-a-url"
                                        }
                                      })

      expect(result.failure?).to be true
      expect(result.errors.first.path).to eq([:profile, :website])
    end
  end

  describe "complex real-world example" do
    let(:schema) do
      address_schema = Validrb.schema do
        field :street, :string
        field :city, :string
        field :state, :string, length: 2
        field :zip, :string, format: /\A\d{5}(-\d{4})?\z/
      end

      contact_schema = Validrb.schema do
        field :type, :string, enum: %w[email phone]
        field :value, :string
      end

      address = address_schema
      contact = contact_schema

      Validrb.schema do
        field :id, :integer
        field :name, :string, min: 1, max: 200
        field :email, :string, format: :email
        field :age, :integer, min: 0, max: 150, optional: true
        field :role, :string, enum: %w[admin user guest], default: "user"
        field :active, :boolean, default: true
        field :tags, :array, of: :string, optional: true
        field :address, :object, schema: address
        field :contacts, :array, of: Validrb::Types::Object.new(schema: contact), optional: true
      end
    end

    it "validates complex data successfully" do
      result = schema.safe_parse({
                                   "id" => "123",
                                   "name" => "John Doe",
                                   "email" => "john@example.com",
                                   "age" => "30",
                                   "active" => "true",
                                   "tags" => %i[ruby rails],
                                   "address" => {
                                     "street" => "123 Main St",
                                     "city" => "Boston",
                                     "state" => "MA",
                                     "zip" => "02101"
                                   },
                                   "contacts" => [
                                     { "type" => "email", "value" => "john.work@example.com" },
                                     { "type" => "phone", "value" => "+1-555-555-5555" }
                                   ]
                                 })

      expect(result.success?).to be true
      expect(result.data[:id]).to eq(123)
      expect(result.data[:age]).to eq(30)
      expect(result.data[:active]).to be true
      expect(result.data[:role]).to eq("user")
      expect(result.data[:tags]).to eq(%w[ruby rails])
      expect(result.data[:contacts].size).to eq(2)
    end
  end
end
