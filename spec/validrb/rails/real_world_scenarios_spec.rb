# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "Real World Scenarios" do
  describe "Multi-step wizard form" do
    let(:step1_form) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "PersonalInfoForm"
        end

        schema do
          field :first_name, :string, min: 1, max: 50
          field :last_name, :string, min: 1, max: 50
          field :email, :string, format: :email
          field :phone, :string, format: /\A\+?[\d\s\-()]+\z/, optional: true
        end
      end
    end

    let(:step2_form) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "AddressForm"
        end

        schema do
          field :street, :string, min: 5
          field :city, :string, min: 2
          field :state, :string, length: 2
          field :zip, :string, format: /\A\d{5}(-\d{4})?\z/
          field :country, :string, default: "US"
        end
      end
    end

    let(:step3_form) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "PaymentForm"
        end

        schema do
          field :card_number, :string, format: /\A\d{13,19}\z/
          field :exp_month, :integer, min: 1, max: 12
          field :exp_year, :integer, min: 2024
          field :cvv, :string, format: /\A\d{3,4}\z/
          field :billing_same_as_shipping, :boolean, default: true
        end
      end
    end

    it "validates each step independently" do
      # Step 1
      form1 = step1_form.new(
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com"
      )
      expect(form1.valid?).to be true

      # Step 2
      form2 = step2_form.new(
        street: "123 Main Street",
        city: "New York",
        state: "NY",
        zip: "10001"
      )
      expect(form2.valid?).to be true

      # Step 3
      form3 = step3_form.new(
        card_number: "4111111111111111",
        exp_month: 12,
        exp_year: 2025,
        cvv: "123"
      )
      expect(form3.valid?).to be true
    end

    it "collects errors at failed step" do
      form = step1_form.new(
        first_name: "",
        last_name: "Doe",
        email: "invalid"
      )
      expect(form.valid?).to be false
      expect(form.errors[:first_name]).not_to be_empty
      expect(form.errors[:email]).not_to be_empty
    end
  end

  describe "Bulk import validation" do
    let(:import_schema) do
      Validrb.schema do
        field :records, :array, min: 1, max: 1000 do
          field :external_id, :string, min: 1
          field :name, :string, min: 1
          field :email, :string, format: :email
          field :amount, :decimal, min: 0
          field :date, :date
        end
        field :options, :object, optional: true do
          field :skip_duplicates, :boolean, default: false
          field :update_existing, :boolean, default: false
          field :dry_run, :boolean, default: false
        end
      end
    end

    it "validates bulk import data" do
      result = import_schema.safe_parse(
        records: [
          { external_id: "EXT-001", name: "Item 1", email: "a@example.com", amount: "100.00", date: "2024-01-15" },
          { external_id: "EXT-002", name: "Item 2", email: "b@example.com", amount: "200.00", date: "2024-01-16" },
          { external_id: "EXT-003", name: "Item 3", email: "c@example.com", amount: "300.00", date: "2024-01-17" }
        ],
        options: { skip_duplicates: true }
      )

      expect(result).to be_success
      expect(result.data[:records].length).to eq(3)
      expect(result.data[:records].first[:amount]).to eq(BigDecimal("100.00"))
    end

    it "reports errors with array indices" do
      result = import_schema.safe_parse(
        records: [
          { external_id: "EXT-001", name: "Item 1", email: "valid@example.com", amount: "100", date: "2024-01-15" },
          { external_id: "", name: "", email: "invalid", amount: "-50", date: "bad-date" }
        ]
      )

      expect(result).to be_failure
      paths = result.errors.to_a.map { |e| e.path.join(".") }
      expect(paths.any? { |p| p.include?("records.1") }).to be true
    end
  end

  describe "API webhook payload validation" do
    let(:webhook_schema) do
      Validrb.schema do
        field :event, :string, enum: %w[order.created order.updated order.cancelled payment.received payment.failed]
        field :timestamp, :datetime
        field :signature, :string, min: 32
        field :data, :object do
          field :id, :string
          field :type, :string
          field :attributes, :object
        end
        field :metadata, :object, optional: true
      end
    end

    it "validates webhook payloads" do
      result = webhook_schema.safe_parse(
        event: "order.created",
        timestamp: "2024-01-15T10:30:00Z",
        signature: "abc123def456abc123def456abc123def456",
        data: {
          id: "ord_123",
          type: "order",
          attributes: { total: 99.99 }
        }
      )

      expect(result).to be_success
      expect(result.data[:event]).to eq("order.created")
    end

    it "rejects invalid events" do
      result = webhook_schema.safe_parse(
        event: "invalid.event",
        timestamp: "2024-01-15T10:30:00Z",
        signature: "abc123def456abc123def456abc123def456",
        data: { id: "123", type: "test", attributes: {} }
      )

      expect(result).to be_failure
    end
  end

  describe "Search and filter parameters" do
    let(:search_schema) do
      Validrb.schema do
        field :query, :string, optional: true, preprocess: ->(v) { v&.strip }
        field :page, :integer, min: 1, default: 1
        field :per_page, :integer, min: 1, max: 100, default: 25
        field :sort_by, :string, enum: %w[created_at updated_at name relevance], default: "relevance"
        field :sort_order, :string, enum: %w[asc desc], default: "desc"
        field :filters, :object, optional: true do
          field :status, :array, of: :string, optional: true
          field :category_ids, :array, of: :integer, optional: true
          field :price_min, :decimal, min: 0, optional: true
          field :price_max, :decimal, min: 0, optional: true
          field :created_after, :date, optional: true
          field :created_before, :date, optional: true
        end

        validate do |data|
          filters = data[:filters]
          next unless filters

          if filters[:price_min] && filters[:price_max] && filters[:price_min] > filters[:price_max]
            error(:"filters.price_min", "must be less than price_max")
          end

          if filters[:created_after] && filters[:created_before] && filters[:created_after] > filters[:created_before]
            error(:"filters.created_after", "must be before created_before")
          end
        end
      end
    end

    it "applies defaults for pagination" do
      result = search_schema.safe_parse({})

      expect(result).to be_success
      expect(result.data[:page]).to eq(1)
      expect(result.data[:per_page]).to eq(25)
      expect(result.data[:sort_by]).to eq("relevance")
    end

    it "validates complex filters" do
      result = search_schema.safe_parse(
        query: "  ruby gems  ",
        page: "2",
        per_page: "50",
        filters: {
          status: %w[active pending],
          category_ids: %w[1 2 3],
          price_min: "10.00",
          price_max: "100.00",
          created_after: "2024-01-01",
          created_before: "2024-12-31"
        }
      )

      expect(result).to be_success
      expect(result.data[:query]).to eq("ruby gems")
      expect(result.data[:filters][:category_ids]).to eq([1, 2, 3])
    end

    it "validates filter ranges" do
      result = search_schema.safe_parse(
        filters: {
          price_min: "100",
          price_max: "50"
        }
      )

      expect(result).to be_failure
      error_paths = result.errors.to_a.map { |e| e.path.join(".") }
      expect(error_paths.any? { |p| p.include?("filters") }).to be true
    end
  end

  describe "User preferences with conditional validation" do
    let(:preferences_schema) do
      Validrb.schema do
        field :notification_type, :string, enum: %w[email sms push none]
        field :email, :string, format: :email, when: ->(data) { data[:notification_type] == "email" }
        field :phone, :string, format: /\A\+\d{10,15}\z/, when: ->(data) { data[:notification_type] == "sms" }
        field :device_token, :string, min: 64, when: ->(data) { data[:notification_type] == "push" }
        field :frequency, :string, enum: %w[immediate daily weekly], default: "immediate",
              unless: ->(data) { data[:notification_type] == "none" }
      end
    end

    it "validates email notification" do
      result = preferences_schema.safe_parse(
        notification_type: "email",
        email: "user@example.com",
        frequency: "daily"
      )

      expect(result).to be_success
    end

    it "validates sms notification" do
      result = preferences_schema.safe_parse(
        notification_type: "sms",
        phone: "+15551234567",
        frequency: "immediate"
      )

      expect(result).to be_success
    end

    it "skips frequency for none" do
      result = preferences_schema.safe_parse(notification_type: "none")

      expect(result).to be_success
    end

    it "requires email for email notification" do
      result = preferences_schema.safe_parse(
        notification_type: "email"
      )

      expect(result).to be_failure
    end
  end

  describe "File upload metadata validation" do
    let(:upload_schema) do
      Validrb.schema do
        field :files, :array, min: 1, max: 10 do
          field :name, :string, format: /\A[\w\-\.]+\z/
          field :size, :integer, min: 1, max: 10_485_760  # 10MB
          field :content_type, :string, enum: %w[
            image/jpeg image/png image/gif image/webp
            application/pdf
            text/plain text/csv
          ]
          field :checksum, :string, format: /\A[a-f0-9]{64}\z/
        end
        field :metadata, :object, optional: true do
          field :description, :string, max: 500, optional: true
          field :tags, :array, of: :string, max: 10, optional: true
          field :folder_id, :integer, optional: true
        end
      end
    end

    it "validates file uploads" do
      result = upload_schema.safe_parse(
        files: [
          {
            name: "document.pdf",
            size: 1_048_576,
            content_type: "application/pdf",
            checksum: "a" * 64
          },
          {
            name: "image.jpg",
            size: 524_288,
            content_type: "image/jpeg",
            checksum: "b" * 64
          }
        ],
        metadata: {
          description: "Important files",
          tags: %w[work important],
          folder_id: 123
        }
      )

      expect(result).to be_success
    end

    it "rejects oversized files" do
      result = upload_schema.safe_parse(
        files: [
          {
            name: "huge.pdf",
            size: 20_000_000,  # 20MB
            content_type: "application/pdf",
            checksum: "a" * 64
          }
        ]
      )

      expect(result).to be_failure
    end

    it "rejects invalid content types" do
      result = upload_schema.safe_parse(
        files: [
          {
            name: "script.exe",
            size: 1000,
            content_type: "application/x-msdownload",
            checksum: "a" * 64
          }
        ]
      )

      expect(result).to be_failure
    end
  end

  describe "Subscription plan validation" do
    let(:subscription_schema) do
      Validrb.schema do
        field :plan, :string, enum: %w[free basic pro enterprise]
        field :billing_cycle, :string, enum: %w[monthly annual], default: "monthly",
              unless: ->(data) { data[:plan] == "free" }
        field :seats, :integer, min: 1, default: 1,
              unless: ->(data) { data[:plan] == "free" }
        field :add_ons, :array, of: :string, optional: true,
              unless: ->(data) { %w[free basic].include?(data[:plan]) }
        field :coupon_code, :string, optional: true

        validate do |data|
          plan = data[:plan]
          seats = data[:seats]

          max_seats = { "free" => 1, "basic" => 5, "pro" => 25, "enterprise" => nil }
          limit = max_seats[plan]

          if limit && seats && seats > limit
            error(:seats, "maximum #{limit} seats allowed for #{plan} plan")
          end

          if data[:add_ons]&.any? && %w[free basic].include?(plan)
            error(:add_ons, "not available for #{plan} plan")
          end
        end
      end
    end

    it "validates free plan" do
      result = subscription_schema.safe_parse(plan: "free")

      expect(result).to be_success
    end

    it "validates pro plan with add-ons" do
      result = subscription_schema.safe_parse(
        plan: "pro",
        billing_cycle: "annual",
        seats: 10,
        add_ons: %w[advanced_analytics priority_support]
      )

      expect(result).to be_success
    end

    it "enforces seat limits" do
      result = subscription_schema.safe_parse(
        plan: "basic",
        seats: 10
      )

      expect(result).to be_failure
      expect(result.errors.to_a.first.message).to include("5 seats")
    end
  end

  describe "API rate limit configuration" do
    let(:rate_limit_schema) do
      Validrb.schema do
        field :rules, :array, min: 1 do
          field :name, :string, min: 1
          field :endpoint_pattern, :string, min: 1
          field :method, :string, enum: %w[GET POST PUT PATCH DELETE *], default: "*"
          field :limit, :integer, min: 1
          field :window_seconds, :integer, min: 1, max: 86400
          field :penalty_seconds, :integer, min: 0, default: 0
          field :exempt_roles, :array, of: :string, optional: true
        end
        field :global_limit, :integer, min: 1, optional: true
        field :enabled, :boolean, default: true
      end
    end

    it "validates rate limit configuration" do
      result = rate_limit_schema.safe_parse(
        rules: [
          {
            name: "api_general",
            endpoint_pattern: "/api/*",
            limit: 100,
            window_seconds: 60
          },
          {
            name: "api_search",
            endpoint_pattern: "/api/search",
            method: "GET",
            limit: 10,
            window_seconds: 60,
            penalty_seconds: 300,
            exempt_roles: %w[admin premium]
          }
        ],
        global_limit: 1000,
        enabled: true
      )

      expect(result).to be_success
      expect(result.data[:rules].first[:method]).to eq("*")
    end
  end

  describe "Form with dynamic field count" do
    let(:survey_schema) do
      Validrb.schema do
        field :title, :string, min: 1, max: 200
        field :description, :string, max: 1000, optional: true
        field :questions, :array, min: 1, max: 50 do
          field :text, :string, min: 1, max: 500
          field :type, :string, enum: %w[text number choice multi_choice scale]
          field :required, :boolean, default: false
          field :options, :array, of: :string, min: 2, max: 10,
                when: ->(data) { %w[choice multi_choice].include?(data[:type]) }
          field :min_value, :integer, when: ->(data) { %w[number scale].include?(data[:type]) }
          field :max_value, :integer, when: ->(data) { %w[number scale].include?(data[:type]) }
        end
      end
    end

    it "validates survey with various question types" do
      result = survey_schema.safe_parse(
        title: "Customer Satisfaction Survey",
        description: "Help us improve",
        questions: [
          { text: "How did you hear about us?", type: "choice", options: %w[Web Friend Ad Other] },
          { text: "Rate your experience", type: "scale", min_value: 1, max_value: 10, required: true },
          { text: "Additional comments", type: "text" }
        ]
      )

      expect(result).to be_success
    end

    it "requires options for choice questions" do
      result = survey_schema.safe_parse(
        title: "Survey",
        questions: [
          { text: "Choose one", type: "choice" }  # Missing options
        ]
      )

      expect(result).to be_failure
    end
  end
end
