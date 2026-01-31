# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "Controller Advanced Features" do
  let(:mock_request) { double("request", present?: true) }

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

  describe "ActionController::Parameters simulation" do
    # Simulate ActionController::Parameters behavior
    let(:ac_params_class) do
      Class.new(Hash) do
        def initialize(hash = {})
          super()
          merge!(hash)
        end

        def to_unsafe_h
          to_h
        end
      end
    end

    before do
      stub_const("ActionController::Parameters", ac_params_class)
    end

    let(:schema) do
      Validrb.schema do
        field :name, :string
        field :email, :string, format: :email
      end
    end

    it "handles ActionController::Parameters" do
      params = ActionController::Parameters.new(
        user: ActionController::Parameters.new(
          name: "John",
          email: "john@example.com"
        )
      )
      controller = controller_class.new(params, mock_request)
      result = controller.validate_params(schema, :user)

      expect(result).to be_success
      expect(result.data[:name]).to eq("John")
    end
  end

  describe "Complex nested params" do
    let(:order_schema) do
      Validrb.schema do
        field :customer, :object do
          field :name, :string
          field :email, :string, format: :email
          field :address, :object do
            field :street, :string
            field :city, :string
            field :country, :string, default: "US"
          end
        end
        field :items, :array do
          field :product_id, :integer
          field :quantity, :integer, min: 1
          field :price, :decimal
        end
        field :notes, :string, optional: true
      end
    end

    it "validates deeply nested params" do
      controller = controller_class.new({
        order: {
          customer: {
            name: "John Doe",
            email: "john@example.com",
            address: {
              street: "123 Main St",
              city: "NYC"
            }
          },
          items: [
            { product_id: "1", quantity: "2", price: "19.99" },
            { product_id: "2", quantity: "1", price: "29.99" }
          ]
        }
      }, mock_request)

      result = controller.validate_params(order_schema, :order)
      expect(result).to be_success
      expect(result.data[:customer][:address][:country]).to eq("US")
      expect(result.data[:items].first[:quantity]).to eq(2)
    end

    it "reports nested errors with paths" do
      controller = controller_class.new({
        order: {
          customer: {
            name: "John",
            email: "invalid",
            address: { street: "", city: "NYC" }
          },
          items: [
            { product_id: "1", quantity: "0", price: "19.99" }
          ]
        }
      }, mock_request)

      result = controller.validate_params(order_schema, :order)
      expect(result).to be_failure
      paths = result.errors.to_a.map { |e| e.path.join(".") }
      expect(paths).to include("customer.email")
    end
  end

  describe "Context with authorization" do
    let(:permission_schema) do
      Validrb.schema do
        field :action, :string, enum: %w[read write delete]
        field :resource_id, :integer

        validate do |data, ctx|
          next unless ctx

          user = ctx[:current_user]
          action = data[:action]

          if action == "delete" && !user&.admin?
            error(:action, "requires admin privileges")
          end

          if action == "write" && user&.readonly?
            error(:action, "not allowed for readonly users")
          end
        end
      end
    end

    it "allows actions based on user permissions" do
      controller = controller_class.new({ action: "read", resource_id: 1 }, mock_request)
      controller.current_user = double("user", admin?: false, readonly?: false)

      result = controller.validate_params(permission_schema)
      expect(result).to be_success
    end

    it "blocks delete for non-admin" do
      controller = controller_class.new({ action: "delete", resource_id: 1 }, mock_request)
      controller.current_user = double("user", admin?: false, readonly?: false)

      result = controller.validate_params(permission_schema)
      expect(result).to be_failure
      expect(result.errors.to_a.first.message).to include("admin")
    end

    it "blocks write for readonly users" do
      controller = controller_class.new({ action: "write", resource_id: 1 }, mock_request)
      controller.current_user = double("user", admin?: false, readonly?: true)

      result = controller.validate_params(permission_schema)
      expect(result).to be_failure
    end
  end

  describe "Multiple schema validation" do
    let(:header_schema) do
      Validrb.schema do
        field :api_version, :string, format: /\Av\d+\z/
        field :client_id, :string, min: 10
      end
    end

    let(:body_schema) do
      Validrb.schema do
        field :data, :object do
          field :type, :string
          field :attributes, :object, optional: true
        end
      end
    end

    it "validates multiple schemas in sequence" do
      controller = controller_class.new({
        headers: { api_version: "v1", client_id: "client12345" },
        body: { data: { type: "users", attributes: { name: "John" } } }
      }, mock_request)

      header_result = controller.validate_params(header_schema, :headers)
      body_result = controller.validate_params(body_schema, :body)

      expect(header_result).to be_success
      expect(body_result).to be_success
    end

    it "collects errors from both schemas" do
      controller = controller_class.new({
        headers: { api_version: "invalid", client_id: "short" },
        body: { data: { type: nil } }
      }, mock_request)

      header_result = controller.validate_params(header_schema, :headers)
      body_result = controller.validate_params(body_schema, :body)

      expect(header_result).to be_failure
      expect(body_result).to be_failure
      expect(header_result.errors.count).to eq(2)
    end
  end

  describe "validate_params! exception handling" do
    let(:schema) do
      Validrb.schema do
        field :required_field, :string
        field :another_field, :integer, min: 0
      end
    end

    it "raises with detailed error information" do
      controller = controller_class.new({ required_field: nil, another_field: -5 }, mock_request)

      expect {
        controller.validate_params!(schema)
      }.to raise_error(Validrb::Rails::Controller::ValidationError) do |error|
        expect(error.errors.count).to eq(2)
        expect(error.result).to be_a(Validrb::Failure)
        expect(error.message).to include("Validation failed")
      end
    end

    it "can be rescued and handled" do
      controller = controller_class.new({ required_field: nil }, mock_request)
      error_response = nil

      begin
        controller.validate_params!(schema)
      rescue Validrb::Rails::Controller::ValidationError => e
        error_response = {
          errors: e.errors.to_a.map { |err| { path: err.path, message: err.message } }
        }
      end

      expect(error_response).not_to be_nil
      expect(error_response[:errors]).not_to be_empty
    end
  end

  describe "Form building with complex schemas" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ComplexForm"
        end

        schema do
          field :title, :string, min: 1
          field :description, :string, optional: true
          field :tags, :array, of: :string, default: []
          field :metadata, :object, optional: true do
            field :author, :string
            field :version, :integer, default: 1
          end
        end
      end
    end

    it "builds form with partial data" do
      controller = controller_class.new({
        post: { title: "Hello", tags: %w[ruby rails] }
      }, mock_request)

      form = controller.build_form(form_class, :post)
      expect(form.title).to eq("Hello")
      expect(form.tags).to eq(%w[ruby rails])
      expect(form.description).to be_nil
    end

    it "builds form and validates" do
      controller = controller_class.new({
        post: { title: "Hello" }
      }, mock_request)

      form = controller.build_form(form_class, :post)
      expect(form.valid?).to be true
      expect(form.attributes[:tags]).to eq([])
    end
  end

  describe "Rate limiting context" do
    let(:rate_limited_schema) do
      Validrb.schema do
        field :action, :string

        validate do |data, ctx|
          next unless ctx && ctx[:rate_limiter]

          unless ctx[:rate_limiter].allow?(ctx[:client_ip])
            error(:base, "Rate limit exceeded")
          end
        end
      end
    end

    it "validates with rate limiter context" do
      rate_limiter = double("rate_limiter")
      allow(rate_limiter).to receive(:allow?).with("192.168.1.1").and_return(true)

      controller = controller_class.new({ action: "test" }, mock_request)
      result = controller.validate_params(
        rate_limited_schema,
        context: { rate_limiter: rate_limiter, client_ip: "192.168.1.1" }
      )

      expect(result).to be_success
    end

    it "fails when rate limited" do
      rate_limiter = double("rate_limiter")
      allow(rate_limiter).to receive(:allow?).with("192.168.1.1").and_return(false)

      controller = controller_class.new({ action: "test" }, mock_request)
      result = controller.validate_params(
        rate_limited_schema,
        context: { rate_limiter: rate_limiter, client_ip: "192.168.1.1" }
      )

      expect(result).to be_failure
      expect(result.errors.to_a.first.message).to include("Rate limit")
    end
  end

  describe "File upload validation" do
    let(:upload_schema) do
      Validrb.schema do
        field :filename, :string, format: /\A[\w\-\.]+\z/
        field :content_type, :string, enum: %w[image/jpeg image/png image/gif application/pdf]
        field :size, :integer, max: 10_000_000  # 10MB

        validate do |data|
          filename = data[:filename].to_s
          content_type = data[:content_type]

          extension = File.extname(filename).downcase
          expected_extensions = {
            "image/jpeg" => [".jpg", ".jpeg"],
            "image/png" => [".png"],
            "image/gif" => [".gif"],
            "application/pdf" => [".pdf"]
          }

          allowed = expected_extensions[content_type] || []
          unless allowed.include?(extension)
            error(:filename, "extension does not match content type")
          end
        end
      end
    end

    it "validates valid upload" do
      controller = controller_class.new({
        filename: "photo.jpg",
        content_type: "image/jpeg",
        size: 1_000_000
      }, mock_request)

      result = controller.validate_params(upload_schema)
      expect(result).to be_success
    end

    it "rejects mismatched extension" do
      controller = controller_class.new({
        filename: "malware.exe",
        content_type: "image/jpeg",
        size: 1_000_000
      }, mock_request)

      result = controller.validate_params(upload_schema)
      expect(result).to be_failure
    end

    it "rejects oversized files" do
      controller = controller_class.new({
        filename: "huge.pdf",
        content_type: "application/pdf",
        size: 20_000_000
      }, mock_request)

      result = controller.validate_params(upload_schema)
      expect(result).to be_failure
    end
  end

  describe "Pagination params" do
    let(:pagination_schema) do
      Validrb.schema do
        field :page, :integer, min: 1, default: 1
        field :per_page, :integer, min: 1, max: 100, default: 25
        field :sort_by, :string, enum: %w[created_at updated_at name], optional: true
        field :sort_order, :string, enum: %w[asc desc], default: "desc"
      end
    end

    it "applies defaults for pagination" do
      controller = controller_class.new({}, mock_request)
      result = controller.validate_params(pagination_schema)

      expect(result).to be_success
      expect(result.data[:page]).to eq(1)
      expect(result.data[:per_page]).to eq(25)
      expect(result.data[:sort_order]).to eq("desc")
    end

    it "coerces string pagination params" do
      controller = controller_class.new({
        page: "5",
        per_page: "50",
        sort_by: "name",
        sort_order: "asc"
      }, mock_request)

      result = controller.validate_params(pagination_schema)
      expect(result).to be_success
      expect(result.data[:page]).to eq(5)
      expect(result.data[:per_page]).to eq(50)
    end

    it "rejects invalid pagination" do
      controller = controller_class.new({
        page: "0",
        per_page: "500"
      }, mock_request)

      result = controller.validate_params(pagination_schema)
      expect(result).to be_failure
      expect(result.errors.count).to eq(2)
    end
  end

  describe "Search/filter params" do
    let(:search_schema) do
      Validrb.schema do
        field :q, :string, optional: true, preprocess: ->(v) { v&.strip }
        field :filters, :object, optional: true do
          field :status, :array, of: :string, optional: true
          field :created_after, :date, optional: true
          field :created_before, :date, optional: true
          field :min_amount, :decimal, optional: true
          field :max_amount, :decimal, optional: true
        end

        validate do |data|
          filters = data[:filters]
          next unless filters

          if filters[:created_after] && filters[:created_before]
            if filters[:created_after] > filters[:created_before]
              error(:"filters.created_after", "must be before created_before")
            end
          end

          if filters[:min_amount] && filters[:max_amount]
            if filters[:min_amount] > filters[:max_amount]
              error(:"filters.min_amount", "must be less than max_amount")
            end
          end
        end
      end
    end

    it "validates search with filters" do
      controller = controller_class.new({
        q: "  ruby gems  ",
        filters: {
          status: %w[active pending],
          created_after: "2024-01-01",
          created_before: "2024-12-31",
          min_amount: "10",
          max_amount: "100"
        }
      }, mock_request)

      result = controller.validate_params(search_schema)
      expect(result).to be_success
      expect(result.data[:q]).to eq("ruby gems")
      expect(result.data[:filters][:created_after]).to eq(Date.new(2024, 1, 1))
    end

    it "rejects invalid date range" do
      controller = controller_class.new({
        filters: {
          created_after: "2024-12-31",
          created_before: "2024-01-01"
        }
      }, mock_request)

      result = controller.validate_params(search_schema)
      expect(result).to be_failure
    end
  end

  describe "Batch operations" do
    let(:batch_schema) do
      Validrb.schema do
        field :operations, :array, min: 1, max: 100 do
          field :action, :string, enum: %w[create update delete]
          field :resource_type, :string
          field :resource_id, :integer, optional: true
          field :data, :object, optional: true
        end

        validate do |data|
          operations = data[:operations] || []

          operations.each_with_index do |op, idx|
            if op[:action] == "create" && op[:resource_id]
              error(:"operations.#{idx}.resource_id", "should not be present for create")
            end

            if %w[update delete].include?(op[:action]) && !op[:resource_id]
              error(:"operations.#{idx}.resource_id", "is required for #{op[:action]}")
            end
          end
        end
      end
    end

    it "validates batch operations" do
      controller = controller_class.new({
        operations: [
          { action: "create", resource_type: "user", data: { name: "John" } },
          { action: "update", resource_type: "user", resource_id: 1, data: { name: "Jane" } },
          { action: "delete", resource_type: "user", resource_id: 2 }
        ]
      }, mock_request)

      result = controller.validate_params(batch_schema)
      expect(result).to be_success
    end

    it "rejects invalid batch operations" do
      controller = controller_class.new({
        operations: [
          { action: "create", resource_type: "user", resource_id: 1 },  # Invalid
          { action: "delete", resource_type: "user" }  # Missing resource_id
        ]
      }, mock_request)

      result = controller.validate_params(batch_schema)
      expect(result).to be_failure
      expect(result.errors.count).to eq(2)
    end
  end
end
