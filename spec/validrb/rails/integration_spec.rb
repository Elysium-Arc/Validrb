# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "Rails Integration End-to-End" do
  describe "E-commerce checkout flow" do
    let(:customer_schema) do
      Validrb.schema do
        field :email, :string, format: :email
        field :name, :string, min: 2
        field :phone, :string, format: /\A\+?\d{10,15}\z/, optional: true
      end
    end

    let(:address_schema) do
      Validrb.schema do
        field :street, :string, min: 5
        field :city, :string, min: 2
        field :state, :string, length: 2
        field :zip, :string, format: /\A\d{5}(-\d{4})?\z/
        field :country, :string, default: "US"
      end
    end

    let(:card_schema) do
      Validrb.schema do
        field :method, :string, literal: ["card"]
        field :number, :string, format: /\A\d{13,19}\z/
        field :exp_month, :integer, min: 1, max: 12
        field :exp_year, :integer, min: 2024
        field :cvv, :string, format: /\A\d{3,4}\z/
      end
    end

    let(:paypal_schema) do
      Validrb.schema do
        field :method, :string, literal: ["paypal"]
        field :email, :string, format: :email
      end
    end

    let(:checkout_form_class) do
      customer = customer_schema
      address = address_schema
      card = card_schema
      paypal = paypal_schema

      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "CheckoutForm"
        end

        schema do
          field :customer, :object, schema: customer
          field :shipping_address, :object, schema: address
          field :billing_address, :object, schema: address, optional: true
          field :same_as_shipping, :boolean, default: false
          field :items, :array, min: 1 do
            field :sku, :string, min: 1
            field :quantity, :integer, min: 1
            field :price, :decimal, min: 0
          end
          field :payment, :discriminated_union,
                discriminator: :method,
                mapping: { "card" => card, "paypal" => paypal }
          field :coupon_code, :string, optional: true
          field :notes, :string, max: 500, optional: true

          validate do |data|
            # Validate billing address when not same as shipping
            if !data[:same_as_shipping] && data[:billing_address].nil?
              error(:billing_address, "is required when different from shipping")
            end

            # Validate card expiration
            if data[:payment]&.dig(:method) == "card"
              exp_month = data[:payment][:exp_month]
              exp_year = data[:payment][:exp_year]
              if exp_year && exp_month
                exp_date = Date.new(exp_year, exp_month, -1)
                if exp_date < Date.today
                  error(:"payment.exp_month", "card has expired")
                end
              end
            end

            # Calculate and validate total
            items = data[:items] || []
            calculated_total = items.sum { |i| (i[:quantity] || 0) * (i[:price] || 0) }
            if calculated_total <= 0
              error(:items, "total must be greater than zero")
            end
          end
        end
      end
    end

    it "validates complete checkout with card" do
      form = checkout_form_class.new(
        customer: {
          email: "john@example.com",
          name: "John Doe"
        },
        shipping_address: {
          street: "123 Main Street",
          city: "New York",
          state: "NY",
          zip: "10001"
        },
        same_as_shipping: true,
        items: [
          { sku: "PROD-001", quantity: 2, price: "29.99" },
          { sku: "PROD-002", quantity: 1, price: "49.99" }
        ],
        payment: {
          method: "card",
          number: "4111111111111111",
          exp_month: 12,
          exp_year: 2026,
          cvv: "123"
        }
      )

      expect(form.valid?).to be true
      expect(form.attributes[:customer][:email]).to eq("john@example.com")
      expect(form.attributes[:items].first[:quantity]).to eq(2)
    end

    it "validates complete checkout with paypal" do
      form = checkout_form_class.new(
        customer: { email: "john@example.com", name: "John Doe" },
        shipping_address: { street: "123 Main St", city: "Boston", state: "MA", zip: "02101" },
        same_as_shipping: true,
        items: [{ sku: "PROD-001", quantity: 1, price: "99.99" }],
        payment: { method: "paypal", email: "john.paypal@example.com" }
      )

      expect(form.valid?).to be true
    end

    it "requires billing address when different" do
      form = checkout_form_class.new(
        customer: { email: "john@example.com", name: "John" },
        shipping_address: { street: "123 Main St", city: "NYC", state: "NY", zip: "10001" },
        same_as_shipping: false,  # Need billing address
        items: [{ sku: "X", quantity: 1, price: "10" }],
        payment: { method: "paypal", email: "john@paypal.com" }
      )

      expect(form.valid?).to be false
      expect(form.errors[:billing_address]).not_to be_empty
    end

    it "detects expired card" do
      form = checkout_form_class.new(
        customer: { email: "john@example.com", name: "John" },
        shipping_address: { street: "123 Main St", city: "NYC", state: "NY", zip: "10001" },
        same_as_shipping: true,
        items: [{ sku: "X", quantity: 1, price: "10" }],
        payment: {
          method: "card",
          number: "4111111111111111",
          exp_month: 1,
          exp_year: 2020,  # Expired
          cvv: "123"
        }
      )

      expect(form.valid?).to be false
    end
  end

  describe "User registration flow" do
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

    let(:registration_schema) do
      Validrb.schema do
        field :username, :string,
              min: 3,
              max: 20,
              format: /\A[a-z0-9_]+\z/,
              preprocess: ->(v) { v&.strip&.downcase }

        field :email, :string,
              format: :email,
              preprocess: ->(v) { v&.strip&.downcase }

        field :password, :string, refine: [
          { check: ->(v) { v.length >= 8 }, message: "must be at least 8 characters" },
          { check: ->(v) { v.match?(/[A-Z]/) }, message: "must contain uppercase letter" },
          { check: ->(v) { v.match?(/[a-z]/) }, message: "must contain lowercase letter" },
          { check: ->(v) { v.match?(/\d/) }, message: "must contain a number" }
        ]

        field :password_confirmation, :string

        field :profile, :object, optional: true do
          field :first_name, :string, optional: true
          field :last_name, :string, optional: true
          field :bio, :string, max: 500, optional: true
          field :website, :string, format: :url, optional: true
        end

        field :terms_accepted, :boolean

        field :marketing_consent, :boolean, default: false

        validate do |data|
          if data[:password] != data[:password_confirmation]
            error(:password_confirmation, "does not match password")
          end

          unless data[:terms_accepted]
            error(:terms_accepted, "must be accepted")
          end
        end
      end
    end

    it "validates complete registration" do
      controller = controller_class.new(
        {
          user: {
            username: "  JohnDoe123  ",
            email: "  JOHN@EXAMPLE.COM  ",
            password: "SecurePass1",
            password_confirmation: "SecurePass1",
            profile: {
              first_name: "John",
              last_name: "Doe",
              bio: "Ruby developer"
            },
            terms_accepted: true
          }
        },
        mock_request
      )

      result = controller.validate_params(registration_schema, :user)
      expect(result).to be_success
      expect(result.data[:username]).to eq("johndoe123")
      expect(result.data[:email]).to eq("john@example.com")
    end

    it "returns all password errors" do
      controller = controller_class.new(
        {
          user: {
            username: "john",
            email: "john@example.com",
            password: "weak",
            password_confirmation: "weak",
            terms_accepted: true
          }
        },
        mock_request
      )

      result = controller.validate_params(registration_schema, :user)
      expect(result).to be_failure
      password_errors = result.errors.to_a.select { |e| e.path.include?(:password) }
      expect(password_errors.length).to be >= 3
    end

    it "requires terms acceptance" do
      controller = controller_class.new(
        {
          user: {
            username: "john",
            email: "john@example.com",
            password: "SecurePass1",
            password_confirmation: "SecurePass1",
            terms_accepted: false
          }
        },
        mock_request
      )

      result = controller.validate_params(registration_schema, :user)
      expect(result).to be_failure
      expect(result.errors.to_a.any? { |e| e.path.include?(:terms_accepted) }).to be true
    end
  end

  describe "API request validation" do
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

    let(:api_user) do
      double("user",
             id: 1,
             admin?: false,
             permissions: %w[read write],
             rate_limit: 1000)
    end

    let(:resource_schema) do
      Validrb.schema do
        field :type, :string, enum: %w[articles comments users]
        field :action, :string, enum: %w[create read update delete]
        field :id, :integer, optional: true
        field :data, :object, optional: true

        validate do |data, ctx|
          next unless ctx

          user = ctx[:current_user]
          action = data[:action]
          resource_type = data[:type]

          # Check permissions
          unless user.permissions.include?(action == "read" ? "read" : "write")
            error(:action, "not permitted for current user")
          end

          # Check admin-only actions
          if action == "delete" && resource_type == "users" && !user.admin?
            error(:action, "deleting users requires admin privileges")
          end

          # Require ID for non-create actions
          if %w[read update delete].include?(action) && data[:id].nil?
            error(:id, "is required for #{action} action")
          end

          # Require data for create/update
          if %w[create update].include?(action) && data[:data].nil?
            error(:data, "is required for #{action} action")
          end
        end
      end
    end

    it "validates permitted action" do
      controller = controller_class.new(
        { type: "articles", action: "read", id: 123 },
        mock_request
      )
      controller.current_user = api_user

      result = controller.validate_params(resource_schema)
      expect(result).to be_success
    end

    it "validates create action with data" do
      controller = controller_class.new(
        { type: "articles", action: "create", data: { title: "New Article" } },
        mock_request
      )
      controller.current_user = api_user

      result = controller.validate_params(resource_schema)
      expect(result).to be_success
    end

    it "rejects admin-only action" do
      controller = controller_class.new(
        { type: "users", action: "delete", id: 456 },
        mock_request
      )
      controller.current_user = api_user  # Not admin

      result = controller.validate_params(resource_schema)
      expect(result).to be_failure
      expect(result.errors.to_a.first.message).to include("admin")
    end

    it "requires ID for update" do
      controller = controller_class.new(
        { type: "articles", action: "update", data: { title: "Updated" } },
        mock_request
      )
      controller.current_user = api_user

      result = controller.validate_params(resource_schema)
      expect(result).to be_failure
      expect(result.errors.to_a.any? { |e| e.path.include?(:id) }).to be true
    end
  end

  describe "Form object to model flow" do
    let(:base_model_class) do
      Class.new do
        include ActiveModel::Model

        class << self
          attr_accessor :_attributes

          def attribute(name, _type = nil)
            @_attributes ||= []
            @_attributes << name
            attr_accessor name
          end

          def name
            "TestModel"
          end
        end

        def initialize(attrs = {})
          attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
        end

        def attributes
          self.class._attributes&.each_with_object({}) do |attr, hash|
            hash[attr.to_s] = send(attr)
          end || {}
        end

        def save
          @saved = true
        end

        def saved?
          @saved
        end
      end
    end

    let(:product_form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ProductForm"
        end

        schema do
          field :name, :string, min: 2, max: 100
          field :price, :decimal, min: 0
          field :quantity, :integer, min: 0, default: 0
          field :category, :string, enum: %w[electronics clothing food]
          field :tags, :array, of: :string, default: []
        end
      end
    end

    let(:product_model_class) do
      base = base_model_class
      Class.new(base) do
        attribute :name
        attribute :price
        attribute :quantity
        attribute :category
        attribute :tags

        def self.name
          "Product"
        end
      end
    end

    it "transfers validated form data to model" do
      # Simulate controller receiving params
      params = {
        name: "Laptop",
        price: "999.99",
        quantity: "10",
        category: "electronics",
        tags: %w[tech computer]
      }

      # Create and validate form
      form = product_form_class.new(params)
      expect(form.valid?).to be true

      # Transfer to model
      model = product_model_class.new(form.attributes)
      expect(model.name).to eq("Laptop")
      expect(model.price).to eq(BigDecimal("999.99"))
      expect(model.quantity).to eq(10)

      # Save model
      model.save
      expect(model.saved?).to be true
    end

    it "does not transfer invalid form data" do
      params = {
        name: "X",  # Too short
        price: "-10",  # Negative
        category: "invalid"
      }

      form = product_form_class.new(params)
      expect(form.valid?).to be false

      # Should not create model with invalid data
      expect(form.errors[:name]).not_to be_empty
      expect(form.errors[:price]).not_to be_empty
      expect(form.errors[:category]).not_to be_empty
    end
  end

  describe "Concurrent validation" do
    let(:schema) do
      Validrb.schema do
        field :id, :integer
        field :value, :string
      end
    end

    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "ConcurrentForm"
        end

        schema do
          field :id, :integer
          field :data, :string
        end
      end
    end

    it "handles concurrent schema validations" do
      results = []
      mutex = Mutex.new

      threads = 50.times.map do |i|
        Thread.new do
          result = schema.safe_parse(id: i, value: "value_#{i}")
          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(50)
      expect(results.all?(&:success?)).to be true
      expect(results.map { |r| r.data[:id] }.sort).to eq((0..49).to_a)
    end

    it "handles concurrent form validations" do
      forms = []
      mutex = Mutex.new

      threads = 50.times.map do |i|
        Thread.new do
          form = form_class.new(id: i, data: "data_#{i}")
          form.valid?
          mutex.synchronize { forms << form }
        end
      end

      threads.each(&:join)

      expect(forms.length).to eq(50)
      expect(forms.all?(&:valid?)).to be true
    end
  end

  describe "Error serialization" do
    let(:schema) do
      Validrb.schema do
        field :user, :object do
          field :name, :string, min: 2
          field :contacts, :array do
            field :type, :string, enum: %w[email phone]
            field :value, :string
          end
        end
      end
    end

    it "produces JSON-serializable errors" do
      result = schema.safe_parse(
        user: {
          name: "J",
          contacts: [
            { type: "invalid", value: "" }
          ]
        }
      )

      expect(result).to be_failure

      # Simulate API error response
      error_response = result.errors.to_a.map do |error|
        {
          path: error.path.join("."),
          message: error.message,
          code: error.code
        }
      end

      json = JSON.generate(errors: error_response)
      parsed = JSON.parse(json)

      expect(parsed["errors"]).to be_an(Array)
      expect(parsed["errors"].first).to have_key("path")
      expect(parsed["errors"].first).to have_key("message")
    end
  end
end
