# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "Controller Edge Cases" do
  let(:mock_request) { double("request") }

  let(:controller_class) do
    Class.new do
      include Validrb::Rails::Controller

      attr_accessor :params, :request, :current_user

      def initialize(params = {}, request = nil)
        @params = params
        @request = request
        @current_user = nil
      end
    end
  end

  describe "Empty params handling" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
      end
    end

    it "handles nil params" do
      controller = controller_class.new(nil, mock_request)
      result = controller.validate_params(schema)

      expect(result).to be_failure
    end

    it "handles empty hash params" do
      controller = controller_class.new({}, mock_request)
      result = controller.validate_params(schema)

      expect(result).to be_failure
    end

    it "handles missing nested key" do
      controller = controller_class.new({ other: "value" }, mock_request)
      result = controller.validate_params(schema, :user)

      expect(result).to be_failure
    end
  end

  describe "Nested params extraction" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
        field :email, :string
      end
    end

    it "extracts params from nested key" do
      controller = controller_class.new(
        { user: { name: "John", email: "john@example.com" } },
        mock_request
      )
      result = controller.validate_params(schema, :user)

      expect(result).to be_success
      expect(result.data[:name]).to eq("John")
    end

    it "extracts params from string key" do
      controller = controller_class.new(
        { "user" => { "name" => "John", "email" => "john@example.com" } },
        mock_request
      )
      result = controller.validate_params(schema, :user)

      expect(result).to be_success
    end

    it "handles deeply nested params" do
      nested_schema = Validrb.schema do
        field :street, :string
        field :city, :string
      end

      controller = controller_class.new(
        {
          user: {
            address: { street: "123 Main", city: "NYC" }
          }
        },
        mock_request
      )

      # Extract user.address
      result = controller.validate_params(nested_schema, :user)
      expect(result).to be_failure  # user has address, not street/city directly
    end
  end

  describe "Context building" do
    let(:context_schema) do
      Validrb.schema do
        field :value, :integer,
              refine: ->(v, ctx) { ctx && ctx[:allowed_values]&.include?(v) },
              message: "not in allowed values"
      end
    end

    it "passes custom context to validation" do
      controller = controller_class.new({ value: 5 }, mock_request)

      result = controller.validate_params(context_schema, context: { allowed_values: [1, 2, 3] })
      expect(result).to be_failure

      result = controller.validate_params(context_schema, context: { allowed_values: [5, 10, 15] })
      expect(result).to be_success
    end

    it "includes request in default context" do
      request_schema = Validrb.schema do
        field :value, :integer,
              refine: ->(v, ctx) { ctx && ctx[:request].present? },
              message: "no request in context"
      end

      controller = controller_class.new({ value: 1 }, mock_request)
      allow(mock_request).to receive(:present?).and_return(true)

      result = controller.validate_params(request_schema)
      expect(result).to be_success
    end

    it "includes current_user when available" do
      user_schema = Validrb.schema do
        field :value, :integer,
              refine: ->(v, ctx) { ctx && ctx[:current_user]&.id == 1 },
              message: "wrong user"
      end

      controller = controller_class.new({ value: 1 }, mock_request)
      controller.current_user = double("user", id: 1)

      result = controller.validate_params(user_schema)
      expect(result).to be_success
    end
  end

  describe "ValidationError exception" do
    let(:schema) do
      Validrb.schema do
        field :name, :string, min: 2
        field :email, :string, format: :email
      end
    end

    it "includes all validation errors" do
      controller = controller_class.new({ name: "a", email: "bad" }, mock_request)

      begin
        controller.validate_params!(schema)
        fail "Expected ValidationError to be raised"
      rescue Validrb::Rails::Controller::ValidationError => e
        expect(e.errors.to_a.length).to eq(2)
      end
    end

    it "has descriptive error message" do
      controller = controller_class.new({ name: "a" }, mock_request)

      begin
        controller.validate_params!(schema)
        fail "Expected ValidationError to be raised"
      rescue Validrb::Rails::Controller::ValidationError => e
        expect(e.message).to include("Validation failed")
      end
    end

    it "provides access to result object" do
      controller = controller_class.new({ name: "a" }, mock_request)

      begin
        controller.validate_params!(schema)
      rescue Validrb::Rails::Controller::ValidationError => e
        expect(e.result).to be_a(Validrb::Failure)
        expect(e.result.errors).to eq(e.errors)
      end
    end
  end

  describe "build_form edge cases" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "BuildForm"
        end

        schema do
          field :title, :string
          field :count, :integer
        end
      end
    end

    it "builds form with root params" do
      controller = controller_class.new({ title: "Test", count: "5" }, mock_request)

      form = controller.build_form(form_class)
      expect(form.title).to eq("Test")
      expect(form.count).to eq("5")  # Not yet validated/coerced
    end

    it "builds form with nested params" do
      controller = controller_class.new(
        { post: { title: "Test", count: "5" } },
        mock_request
      )

      form = controller.build_form(form_class, :post)
      expect(form.title).to eq("Test")
    end

    it "builds form with empty params" do
      controller = controller_class.new({}, mock_request)

      form = controller.build_form(form_class)
      expect(form.title).to be_nil
      expect(form.count).to be_nil
    end

    it "builds form with nil nested key" do
      controller = controller_class.new({ other: "value" }, mock_request)

      form = controller.build_form(form_class, :post)
      expect(form.title).to be_nil
    end
  end

  describe "Concurrent controller usage" do
    let(:schema) do
      Validrb.schema do
        field :id, :integer
      end
    end

    it "handles concurrent validations" do
      results = []
      mutex = Mutex.new

      threads = 20.times.map do |i|
        Thread.new do
          controller = controller_class.new({ id: i.to_s }, mock_request)
          result = controller.validate_params(schema)
          mutex.synchronize { results << result.data[:id] }
        end
      end

      threads.each(&:join)

      expect(results.sort).to eq((0..19).to_a)
    end
  end

  describe "Special param values" do
    let(:schema) do
      Validrb.schema do
        field :value, :string
      end
    end

    it "handles params with array values" do
      controller = controller_class.new({ value: %w[a b c] }, mock_request)
      result = controller.validate_params(schema)

      # Array should fail string validation
      expect(result).to be_failure
    end

    it "handles params with hash values" do
      controller = controller_class.new({ value: { nested: "hash" } }, mock_request)
      result = controller.validate_params(schema)

      # Hash should fail string validation
      expect(result).to be_failure
    end

    it "handles params with nil values" do
      controller = controller_class.new({ value: nil }, mock_request)
      result = controller.validate_params(schema)

      expect(result).to be_failure
    end

    it "handles params with empty string" do
      string_schema = Validrb.schema do
        field :value, :string, min: 1
      end

      controller = controller_class.new({ value: "" }, mock_request)
      result = controller.validate_params(string_schema)

      expect(result).to be_failure
    end
  end

  describe "Schema with all field types" do
    let(:comprehensive_schema) do
      Validrb.schema do
        field :string_field, :string
        field :integer_field, :integer
        field :float_field, :float
        field :boolean_field, :boolean
        field :date_field, :date
        field :array_field, :array, of: :string
        field :object_field, :object do
          field :nested, :string
        end
      end
    end

    it "validates all field types from params" do
      controller = controller_class.new(
        {
          string_field: "test",
          integer_field: "42",
          float_field: "3.14",
          boolean_field: "true",
          date_field: "2024-01-15",
          array_field: %w[a b c],
          object_field: { nested: "value" }
        },
        mock_request
      )

      result = controller.validate_params(comprehensive_schema)
      expect(result).to be_success

      expect(result.data[:string_field]).to eq("test")
      expect(result.data[:integer_field]).to eq(42)
      expect(result.data[:float_field]).to eq(3.14)
      expect(result.data[:boolean_field]).to eq(true)
      expect(result.data[:date_field]).to eq(Date.new(2024, 1, 15))
      expect(result.data[:array_field]).to eq(%w[a b c])
      expect(result.data[:object_field]).to eq({ nested: "value" })
    end
  end
end
