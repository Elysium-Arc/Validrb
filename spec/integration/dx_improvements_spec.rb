# frozen_string_literal: true

require "spec_helper"

RSpec.describe "DX Improvements" do
  describe "Inline nested schemas" do
    describe "object with inline schema" do
      let(:schema) do
        Validrb.schema do
          field :name, :string
          field :address, :object do
            field :street, :string
            field :city, :string
            field :zip, :string, format: /\A\d{5}\z/
          end
        end
      end

      it "validates nested object with inline schema" do
        result = schema.safe_parse(
          name: "John",
          address: { street: "123 Main St", city: "NYC", zip: "10001" }
        )

        expect(result).to be_success
        expect(result.data[:address][:city]).to eq("NYC")
      end

      it "reports errors with correct path" do
        result = schema.safe_parse(
          name: "John",
          address: { street: "123 Main St", city: "NYC", zip: "invalid" }
        )

        expect(result).to be_failure
        expect(result.errors.first.path).to eq([:address, :zip])
      end

      it "validates missing nested fields" do
        result = schema.safe_parse(
          name: "John",
          address: { street: "123 Main St" }
        )

        expect(result).to be_failure
        paths = result.errors.map(&:path)
        expect(paths).to include([:address, :city])
        expect(paths).to include([:address, :zip])
      end
    end

    describe "array with inline item schema" do
      let(:schema) do
        Validrb.schema do
          field :order_id, :integer
          field :items, :array do
            field :product_id, :integer
            field :quantity, :integer, min: 1
            field :notes, :string, optional: true
          end
        end
      end

      it "validates array items with inline schema" do
        result = schema.safe_parse(
          order_id: 1,
          items: [
            { product_id: 100, quantity: 2 },
            { product_id: 101, quantity: 1, notes: "Gift wrap" }
          ]
        )

        expect(result).to be_success
        expect(result.data[:items].length).to eq(2)
        expect(result.data[:items][0][:product_id]).to eq(100)
        expect(result.data[:items][1][:notes]).to eq("Gift wrap")
      end

      it "reports errors with correct array index path" do
        result = schema.safe_parse(
          order_id: 1,
          items: [
            { product_id: 100, quantity: 2 },
            { product_id: 101, quantity: 0 } # Invalid: min 1
          ]
        )

        expect(result).to be_failure
        expect(result.errors.first.path).to eq([:items, 1, :quantity])
      end

      it "validates all items" do
        result = schema.safe_parse(
          order_id: 1,
          items: [
            { product_id: 100 }, # Missing quantity
            { quantity: 1 }      # Missing product_id
          ]
        )

        expect(result).to be_failure
        paths = result.errors.map(&:path)
        expect(paths).to include([:items, 0, :quantity])
        expect(paths).to include([:items, 1, :product_id])
      end
    end

    describe "deeply nested inline schemas" do
      let(:schema) do
        Validrb.schema do
          field :company, :object do
            field :name, :string
            field :headquarters, :object do
              field :address, :object do
                field :street, :string
                field :city, :string
              end
              field :employees, :integer
            end
          end
        end
      end

      it "validates deeply nested structures" do
        result = schema.safe_parse(
          company: {
            name: "Acme Corp",
            headquarters: {
              address: { street: "123 Main", city: "NYC" },
              employees: 100
            }
          }
        )

        expect(result).to be_success
        expect(result.data[:company][:headquarters][:address][:city]).to eq("NYC")
      end

      it "reports errors at correct deep path" do
        result = schema.safe_parse(
          company: {
            name: "Acme Corp",
            headquarters: {
              address: { street: "123 Main" }, # Missing city
              employees: 100
            }
          }
        )

        expect(result).to be_failure
        expect(result.errors.first.path).to eq([:company, :headquarters, :address, :city])
      end
    end

    describe "optional with inline block" do
      let(:schema) do
        Validrb.schema do
          field :name, :string
          optional :metadata, :object do
            field :created_by, :string
            field :version, :integer, default: 1
          end
        end
      end

      it "allows missing optional nested object" do
        result = schema.safe_parse(name: "Test")
        expect(result).to be_success
        expect(result.data[:metadata]).to be_nil
      end

      it "validates optional nested object when present" do
        result = schema.safe_parse(
          name: "Test",
          metadata: { created_by: "admin" }
        )

        expect(result).to be_success
        expect(result.data[:metadata][:created_by]).to eq("admin")
        expect(result.data[:metadata][:version]).to eq(1)
      end
    end
  end

  describe "Array of schemas shorthand" do
    describe "passing Schema instance to of:" do
      let(:item_schema) do
        Validrb.schema do
          field :id, :integer
          field :name, :string
        end
      end

      let(:schema) do
        item = item_schema
        Validrb.schema do
          field :items, :array, of: item
        end
      end

      it "validates array items using schema" do
        result = schema.safe_parse(
          items: [
            { id: 1, name: "First" },
            { id: 2, name: "Second" }
          ]
        )

        expect(result).to be_success
        expect(result.data[:items].length).to eq(2)
      end

      it "reports errors from schema validation" do
        result = schema.safe_parse(
          items: [
            { id: 1, name: "First" },
            { id: "invalid", name: "Second" }
          ]
        )

        expect(result).to be_failure
        expect(result.errors.first.path).to eq([:items, 1, :id])
      end
    end

    describe "combining with min/max constraints" do
      let(:item_schema) do
        Validrb.schema do
          field :value, :integer
        end
      end

      let(:schema) do
        item = item_schema
        Validrb.schema do
          field :items, :array, of: item, min: 1, max: 3
        end
      end

      it "validates array length constraints" do
        result = schema.safe_parse(items: [])
        expect(result).to be_failure

        result = schema.safe_parse(items: [{ value: 1 }])
        expect(result).to be_success

        result = schema.safe_parse(items: [{ value: 1 }, { value: 2 }, { value: 3 }, { value: 4 }])
        expect(result).to be_failure
      end
    end
  end

  describe "OpenAPI convenience methods" do
    let(:generator) { Validrb::OpenAPI::Generator.new }

    let(:user_schema) do
      Validrb.schema do
        field :name, :string, min: 1
        field :email, :string, format: :email
        field :age, :integer, optional: true
      end
    end

    describe "#request_body" do
      it "generates request body structure" do
        body = generator.request_body(user_schema)

        expect(body["required"]).to be true
        expect(body["content"]).to have_key("application/json")
        expect(body["content"]["application/json"]["schema"]["type"]).to eq("object")
        expect(body["content"]["application/json"]["schema"]["properties"]).to have_key("name")
      end

      it "allows custom content type" do
        body = generator.request_body(user_schema, content_type: "application/xml")

        expect(body["content"]).to have_key("application/xml")
      end

      it "allows optional request body" do
        body = generator.request_body(user_schema, required: false)

        expect(body["required"]).to be false
      end
    end

    describe "#query_params" do
      it "generates query parameters from schema" do
        params = generator.query_params(user_schema)

        expect(params.length).to eq(3)

        name_param = params.find { |p| p["name"] == "name" }
        expect(name_param["in"]).to eq("query")
        expect(name_param["required"]).to be true
        expect(name_param["schema"]["type"]).to eq("string")

        age_param = params.find { |p| p["name"] == "age" }
        expect(age_param["required"]).to be false
      end
    end

    describe "#path_params" do
      it "generates path parameters" do
        params = generator.path_params(:id, :slug)

        expect(params.length).to eq(2)
        expect(params[0]["name"]).to eq("id")
        expect(params[0]["in"]).to eq("path")
        expect(params[0]["required"]).to be true
        expect(params[0]["schema"]["type"]).to eq("string")
      end

      it "allows type overrides" do
        params = generator.path_params(:id, :slug, types: { id: :integer })

        expect(params[0]["schema"]["type"]).to eq("integer")
        expect(params[1]["schema"]["type"]).to eq("string")
      end
    end

    describe "#response_schema" do
      it "generates response with schema" do
        response = generator.response_schema(user_schema, description: "User data")

        expect(response["description"]).to eq("User data")
        expect(response["content"]["application/json"]["schema"]["type"]).to eq("object")
      end
    end

    describe "#response" do
      it "generates simple response" do
        response = generator.response("Created")

        expect(response["description"]).to eq("Created")
        expect(response).not_to have_key("content")
      end
    end

    describe "#error_response" do
      it "generates standard error response" do
        response = generator.error_response(description: "Validation failed")

        expect(response["description"]).to eq("Validation failed")
        expect(response["content"]["application/json"]["schema"]["properties"]).to have_key("error")
        expect(response["content"]["application/json"]["schema"]["properties"]).to have_key("details")
      end
    end

    describe "complete API example" do
      it "builds complete OpenAPI spec with convenience methods" do
        path_builder = Validrb::OpenAPI::PathBuilder.new(generator)
        path_builder
          .post("/users", schema: user_schema, summary: "Create user")
          .get("/users", schema: user_schema, summary: "List users")

        spec = generator.generate(
          info: { title: "Test API", version: "1.0.0" },
          paths: path_builder.to_h
        )

        expect(spec["openapi"]).to eq("3.0.3")
        expect(spec["paths"]["/users"]["post"]["requestBody"]).to be_a(Hash)
        expect(spec["paths"]["/users"]["get"]["parameters"]).to be_an(Array)
      end
    end
  end
end
