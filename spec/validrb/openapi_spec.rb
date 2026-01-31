# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::OpenAPI do
  describe Validrb::OpenAPI::Generator do
    let(:generator) { described_class.new }

    let(:user_schema) do
      Validrb.schema do
        field :id, :integer
        field :name, :string, min: 1, max: 100
        field :email, :string, format: :email
        field :age, :integer, optional: true, min: 0, max: 150
        field :role, :string, enum: %w[admin user guest], default: "user"
      end
    end

    describe "#register" do
      it "registers a schema with a name" do
        generator.register("User", user_schema)
        expect(generator.schemas).to have_key("User")
      end

      it "returns self for chaining" do
        result = generator.register("User", user_schema)
        expect(result).to eq(generator)
      end
    end

    describe "#schema_to_openapi" do
      it "generates OpenAPI schema from Validrb schema" do
        openapi = generator.schema_to_openapi(user_schema)

        expect(openapi["type"]).to eq("object")
        expect(openapi["properties"]).to be_a(Hash)
        expect(openapi["required"]).to include("id", "name", "email")
      end

      it "maps string type correctly" do
        schema = Validrb.schema { field :name, :string }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["name"]["type"]).to eq("string")
      end

      it "maps integer type correctly" do
        schema = Validrb.schema { field :count, :integer }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["count"]["type"]).to eq("integer")
      end

      it "maps float type correctly" do
        schema = Validrb.schema { field :price, :float }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["price"]["type"]).to eq("number")
        expect(openapi["properties"]["price"]["format"]).to eq("float")
      end

      it "maps decimal type correctly" do
        schema = Validrb.schema { field :amount, :decimal }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["amount"]["type"]).to eq("number")
        expect(openapi["properties"]["amount"]["format"]).to eq("double")
      end

      it "maps boolean type correctly" do
        schema = Validrb.schema { field :active, :boolean }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["active"]["type"]).to eq("boolean")
      end

      it "maps date type correctly" do
        schema = Validrb.schema { field :birth_date, :date }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["birth_date"]["type"]).to eq("string")
        expect(openapi["properties"]["birth_date"]["format"]).to eq("date")
      end

      it "maps datetime type correctly" do
        schema = Validrb.schema { field :created_at, :datetime }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["created_at"]["type"]).to eq("string")
        expect(openapi["properties"]["created_at"]["format"]).to eq("date-time")
      end

      it "maps array type correctly" do
        schema = Validrb.schema { field :tags, :array, of: :string }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["tags"]["type"]).to eq("array")
        expect(openapi["properties"]["tags"]["items"]["type"]).to eq("string")
      end

      it "maps nested object correctly" do
        address_schema = Validrb.schema do
          field :street, :string
          field :city, :string
        end

        schema = Validrb.schema do
          field :address, :object, schema: address_schema
        end

        openapi = generator.schema_to_openapi(schema)
        expect(openapi["properties"]["address"]["type"]).to eq("object")
        expect(openapi["properties"]["address"]["properties"]).to have_key("street")
      end
    end

    describe "constraint mapping" do
      it "maps min constraint for numbers" do
        schema = Validrb.schema { field :age, :integer, min: 0 }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["age"]["minimum"]).to eq(0)
      end

      it "maps max constraint for numbers" do
        schema = Validrb.schema { field :age, :integer, max: 150 }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["age"]["maximum"]).to eq(150)
      end

      it "maps min constraint for strings as minLength" do
        schema = Validrb.schema { field :name, :string, min: 1 }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["name"]["minLength"]).to eq(1)
      end

      it "maps max constraint for strings as maxLength" do
        schema = Validrb.schema { field :name, :string, max: 100 }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["name"]["maxLength"]).to eq(100)
      end

      it "maps length constraint" do
        schema = Validrb.schema { field :code, :string, length: { min: 4, max: 8 } }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["code"]["minLength"]).to eq(4)
        expect(openapi["properties"]["code"]["maxLength"]).to eq(8)
      end

      it "maps email format" do
        schema = Validrb.schema { field :email, :string, format: :email }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["email"]["format"]).to eq("email")
      end

      it "maps url format as uri" do
        schema = Validrb.schema { field :website, :string, format: :url }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["website"]["format"]).to eq("uri")
      end

      it "maps uuid format" do
        schema = Validrb.schema { field :id, :string, format: :uuid }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["id"]["format"]).to eq("uuid")
      end

      it "maps custom regex as pattern" do
        schema = Validrb.schema { field :code, :string, format: /\A[A-Z]{3}\z/ }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["code"]["pattern"]).to eq("\\A[A-Z]{3}\\z")
      end

      it "maps enum constraint" do
        schema = Validrb.schema { field :status, :string, enum: %w[active inactive] }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["status"]["enum"]).to eq(%w[active inactive])
      end
    end

    describe "field options" do
      it "marks optional fields as not required" do
        schema = Validrb.schema do
          field :name, :string
          field :nickname, :string, optional: true
        end

        openapi = generator.schema_to_openapi(schema)
        expect(openapi["required"]).to include("name")
        expect(openapi["required"]).not_to include("nickname")
      end

      it "marks nullable fields" do
        schema = Validrb.schema { field :deleted_at, :datetime, nullable: true }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["deleted_at"]["nullable"]).to be true
      end

      it "includes default values" do
        schema = Validrb.schema { field :role, :string, default: "user" }
        openapi = generator.schema_to_openapi(schema)

        expect(openapi["properties"]["role"]["default"]).to eq("user")
      end

      it "excludes fields with defaults from required" do
        schema = Validrb.schema do
          field :name, :string
          field :role, :string, default: "user"
        end

        openapi = generator.schema_to_openapi(schema)
        expect(openapi["required"]).to include("name")
        expect(openapi["required"]).not_to include("role")
      end
    end

    describe "#generate" do
      before do
        generator.register("User", user_schema)
      end

      it "generates a complete OpenAPI document" do
        doc = generator.generate(
          info: { title: "My API", version: "1.0.0" }
        )

        expect(doc["openapi"]).to eq("3.0.3")
        expect(doc["info"]["title"]).to eq("My API")
        expect(doc["info"]["version"]).to eq("1.0.0")
        expect(doc["components"]["schemas"]).to have_key("User")
      end

      it "includes servers" do
        doc = generator.generate(
          info: { title: "API", version: "1.0.0" },
          servers: ["https://api.example.com", { url: "https://staging.example.com" }]
        )

        expect(doc["servers"].size).to eq(2)
        expect(doc["servers"][0]["url"]).to eq("https://api.example.com")
      end

      it "includes paths" do
        doc = generator.generate(
          info: { title: "API", version: "1.0.0" },
          paths: {
            "/users" => {
              "get" => { "summary" => "List users" }
            }
          }
        )

        expect(doc["paths"]["/users"]["get"]["summary"]).to eq("List users")
      end
    end

    describe "#to_json" do
      it "generates JSON output" do
        generator.register("User", user_schema)
        json = generator.to_json(info: { title: "API", version: "1.0.0" })

        expect(json).to be_a(String)
        parsed = JSON.parse(json)
        expect(parsed["openapi"]).to eq("3.0.3")
      end
    end

    describe "#to_yaml" do
      it "generates YAML output" do
        generator.register("User", user_schema)
        yaml = generator.to_yaml(info: { title: "API", version: "1.0.0" })

        expect(yaml).to be_a(String)
        expect(yaml).to include("openapi:")
      end
    end
  end

  describe Validrb::OpenAPI::PathBuilder do
    let(:generator) { Validrb::OpenAPI::Generator.new }
    let(:builder) { described_class.new(generator) }

    let(:user_schema) do
      Validrb.schema do
        field :name, :string
        field :email, :string, format: :email
      end
    end

    describe "#post" do
      it "creates a POST endpoint" do
        builder.post("/users", schema: user_schema, summary: "Create user")
        paths = builder.to_h

        expect(paths["/users"]["post"]).to be_a(Hash)
        expect(paths["/users"]["post"]["summary"]).to eq("Create user")
        expect(paths["/users"]["post"]["requestBody"]).to be_a(Hash)
      end

      it "includes schema in request body" do
        builder.post("/users", schema: user_schema)
        paths = builder.to_h

        body_schema = paths["/users"]["post"]["requestBody"]["content"]["application/json"]["schema"]
        expect(body_schema["properties"]).to have_key("name")
      end
    end

    describe "#put" do
      it "creates a PUT endpoint" do
        builder.put("/users/{id}", schema: user_schema, summary: "Update user")
        paths = builder.to_h

        expect(paths["/users/{id}"]["put"]).to be_a(Hash)
      end
    end

    describe "#patch" do
      it "creates a PATCH endpoint" do
        builder.patch("/users/{id}", schema: user_schema, summary: "Partial update")
        paths = builder.to_h

        expect(paths["/users/{id}"]["patch"]).to be_a(Hash)
      end
    end

    describe "#get" do
      it "creates a GET endpoint" do
        builder.get("/users", summary: "List users")
        paths = builder.to_h

        expect(paths["/users"]["get"]).to be_a(Hash)
        expect(paths["/users"]["get"]["summary"]).to eq("List users")
      end

      it "converts schema to query parameters" do
        query_schema = Validrb.schema do
          field :page, :integer, default: 1
          field :per_page, :integer, default: 20
        end

        builder.get("/users", schema: query_schema)
        paths = builder.to_h

        params = paths["/users"]["get"]["parameters"]
        expect(params).to be_a(Array)
        expect(params.find { |p| p["name"] == "page" }).to be_a(Hash)
      end
    end

    describe "method chaining" do
      it "allows chaining multiple endpoints" do
        paths = builder
          .get("/users", summary: "List")
          .post("/users", schema: user_schema, summary: "Create")
          .get("/users/{id}", summary: "Show")
          .put("/users/{id}", schema: user_schema, summary: "Update")
          .to_h

        expect(paths["/users"]["get"]).to be_a(Hash)
        expect(paths["/users"]["post"]).to be_a(Hash)
        expect(paths["/users/{id}"]["get"]).to be_a(Hash)
        expect(paths["/users/{id}"]["put"]).to be_a(Hash)
      end
    end
  end

  describe "Schema#to_openapi" do
    it "generates OpenAPI schema from a Validrb schema" do
      schema = Validrb.schema do
        field :name, :string
        field :age, :integer, min: 0
      end

      openapi = schema.to_openapi
      expect(openapi["type"]).to eq("object")
      expect(openapi["properties"]["name"]["type"]).to eq("string")
      expect(openapi["properties"]["age"]["minimum"]).to eq(0)
    end
  end

  describe "complex schemas" do
    it "handles union types" do
      schema = Validrb.schema do
        field :id, :string, union: [:integer, :string]
      end

      generator = Validrb::OpenAPI::Generator.new
      openapi = generator.schema_to_openapi(schema)

      expect(openapi["properties"]["id"]["oneOf"]).to be_a(Array)
    end

    it "handles literal types" do
      schema = Validrb.schema do
        field :status, :string, literal: %w[active pending]
      end

      generator = Validrb::OpenAPI::Generator.new
      openapi = generator.schema_to_openapi(schema)

      expect(openapi["properties"]["status"]["enum"]).to eq(%w[active pending])
    end

    it "handles discriminated unions" do
      dog_schema = Validrb.schema do
        field :type, :string
        field :breed, :string
      end

      cat_schema = Validrb.schema do
        field :type, :string
        field :color, :string
      end

      schema = Validrb.schema do
        field :pet, :discriminated_union,
              discriminator: :type,
              mapping: { "dog" => dog_schema, "cat" => cat_schema }
      end

      generator = Validrb::OpenAPI::Generator.new
      openapi = generator.schema_to_openapi(schema)

      expect(openapi["properties"]["pet"]["oneOf"]).to be_a(Array)
      expect(openapi["properties"]["pet"]["oneOf"].size).to eq(2)
    end
  end

  describe Validrb::OpenAPI::Importer do
    let(:importer) { described_class.new }

    describe "#import_schema" do
      it "imports a basic object schema" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string" },
            "age" => { "type" => "integer" }
          },
          "required" => ["name"]
        }

        schema = importer.import_schema(json_schema)

        expect(schema).to be_a(Validrb::Schema)
        expect(schema.field_names).to include(:name, :age)
        expect(schema.field(:name).required?).to be true
        expect(schema.field(:age).optional?).to be true
      end

      it "imports string type" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string" }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:name).type).to be_a(Validrb::Types::String)
      end

      it "imports integer type" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "count" => { "type" => "integer" }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:count).type).to be_a(Validrb::Types::Integer)
      end

      it "imports number type as float" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "price" => { "type" => "number" }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:price).type).to be_a(Validrb::Types::Float)
      end

      it "imports boolean type" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "active" => { "type" => "boolean" }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:active).type).to be_a(Validrb::Types::Boolean)
      end

      it "imports date format" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "birth_date" => { "type" => "string", "format" => "date" }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:birth_date).type).to be_a(Validrb::Types::Date)
      end

      it "imports date-time format" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "created_at" => { "type" => "string", "format" => "date-time" }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:created_at).type).to be_a(Validrb::Types::DateTime)
      end

      it "imports minLength and maxLength" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string", "minLength" => 1, "maxLength" => 100 }
          }
        }

        schema = importer.import_schema(json_schema)
        constraints = schema.field(:name).constraint_values
        expect(constraints[:min]).to eq(1)
        expect(constraints[:max]).to eq(100)
      end

      it "imports minimum and maximum" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "age" => { "type" => "integer", "minimum" => 0, "maximum" => 150 }
          }
        }

        schema = importer.import_schema(json_schema)
        constraints = schema.field(:age).constraint_values
        expect(constraints[:min]).to eq(0)
        expect(constraints[:max]).to eq(150)
      end

      it "imports enum" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "status" => { "type" => "string", "enum" => ["active", "inactive"] }
          }
        }

        schema = importer.import_schema(json_schema)
        constraints = schema.field(:status).constraint_values
        expect(constraints[:enum]).to eq(["active", "inactive"])
      end

      it "imports pattern as format" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "code" => { "type" => "string", "pattern" => "^[A-Z]{3}$" }
          }
        }

        schema = importer.import_schema(json_schema)
        constraints = schema.field(:code).constraint_values
        expect(constraints[:format]).to be_a(Regexp)
      end

      it "imports email format" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "email" => { "type" => "string", "format" => "email" }
          }
        }

        schema = importer.import_schema(json_schema)
        constraints = schema.field(:email).constraint_values
        # Format constraint stores the resolved regex pattern
        expect(constraints[:format]).to be_a(Regexp)
      end

      it "imports nullable fields" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "deleted_at" => { "type" => "string", "format" => "date-time", "nullable" => true }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:deleted_at).nullable?).to be true
      end

      it "imports default values" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "role" => { "type" => "string", "default" => "user" }
          }
        }

        schema = importer.import_schema(json_schema)
        expect(schema.field(:role).has_default?).to be true
        expect(schema.field(:role).default_value).to eq("user")
      end

      it "parses JSON string input" do
        json_string = '{"type":"object","properties":{"name":{"type":"string"}}}'
        schema = importer.import_schema(json_string)

        expect(schema.field_names).to include(:name)
      end
    end

    describe "#import_openapi" do
      it "imports schemas from OpenAPI 3.0 components" do
        openapi_doc = {
          "openapi" => "3.0.3",
          "info" => { "title" => "Test API", "version" => "1.0.0" },
          "components" => {
            "schemas" => {
              "User" => {
                "type" => "object",
                "properties" => {
                  "id" => { "type" => "integer" },
                  "name" => { "type" => "string" }
                },
                "required" => ["id", "name"]
              },
              "Post" => {
                "type" => "object",
                "properties" => {
                  "title" => { "type" => "string" },
                  "content" => { "type" => "string" }
                }
              }
            }
          }
        }

        importer.import_openapi(openapi_doc)

        expect(importer.schema_names).to include("User", "Post")
        expect(importer["User"]).to be_a(Validrb::Schema)
        expect(importer["Post"]).to be_a(Validrb::Schema)
      end

      it "imports schemas from OpenAPI 2.0 definitions" do
        swagger_doc = {
          "swagger" => "2.0",
          "info" => { "title" => "Test API", "version" => "1.0.0" },
          "definitions" => {
            "User" => {
              "type" => "object",
              "properties" => {
                "name" => { "type" => "string" }
              }
            }
          }
        }

        importer.import_openapi(swagger_doc)
        expect(importer["User"]).to be_a(Validrb::Schema)
      end
    end

    describe "imported schema validation" do
      it "validates data correctly" do
        json_schema = {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string", "minLength" => 1 },
            "age" => { "type" => "integer", "minimum" => 0 }
          },
          "required" => ["name"]
        }

        schema = importer.import_schema(json_schema)

        # Valid data
        result = schema.safe_parse({ name: "John", age: 25 })
        expect(result.success?).to be true

        # Missing required field
        result = schema.safe_parse({ age: 25 })
        expect(result.failure?).to be true

        # Constraint violation
        result = schema.safe_parse({ name: "", age: 25 })
        expect(result.failure?).to be true
      end
    end
  end

  describe "OpenAPI.import" do
    it "provides a convenience method for importing" do
      doc = {
        "components" => {
          "schemas" => {
            "User" => {
              "type" => "object",
              "properties" => { "name" => { "type" => "string" } }
            }
          }
        }
      }

      importer = Validrb::OpenAPI.import(doc)
      expect(importer["User"]).to be_a(Validrb::Schema)
    end
  end

  describe "OpenAPI.import_schema" do
    it "imports a single schema directly" do
      json_schema = {
        "type" => "object",
        "properties" => { "name" => { "type" => "string" } }
      }

      schema = Validrb::OpenAPI.import_schema(json_schema)
      expect(schema).to be_a(Validrb::Schema)
    end
  end

  describe "full API example" do
    it "generates a complete API spec" do
      user_schema = Validrb.schema do
        field :name, :string, min: 1, max: 100
        field :email, :string, format: :email
        field :role, :string, enum: %w[admin user], default: "user"
      end

      create_user_schema = Validrb.schema do
        field :name, :string, min: 1, max: 100
        field :email, :string, format: :email
        field :password, :string, min: 8
      end

      generator = Validrb::OpenAPI::Generator.new
      generator.register("User", user_schema)
      generator.register("CreateUser", create_user_schema)

      paths = Validrb::OpenAPI::PathBuilder.new(generator)
        .get("/users", summary: "List users")
        .post("/users", schema: create_user_schema, summary: "Create user")
        .get("/users/{id}", summary: "Get user")
        .to_h

      doc = generator.generate(
        info: {
          title: "User API",
          version: "1.0.0",
          description: "API for managing users"
        },
        servers: ["https://api.example.com"],
        paths: paths
      )

      expect(doc["openapi"]).to eq("3.0.3")
      expect(doc["info"]["title"]).to eq("User API")
      expect(doc["paths"]["/users"]["get"]).to be_a(Hash)
      expect(doc["paths"]["/users"]["post"]).to be_a(Hash)
      expect(doc["components"]["schemas"]["User"]).to be_a(Hash)
      expect(doc["components"]["schemas"]["CreateUser"]).to be_a(Hash)
    end
  end
end
