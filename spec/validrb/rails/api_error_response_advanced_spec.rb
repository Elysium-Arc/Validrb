# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "ApiErrorResponse Advanced Features" do
  let(:controller_class) do
    Class.new do
      include Validrb::Rails::ApiErrorResponse

      attr_accessor :rendered_json, :rendered_status

      def render(json:, status:)
        @rendered_json = json
        @rendered_status = status
      end
    end
  end

  let(:controller) { controller_class.new }

  describe "Complex nested errors" do
    let(:errors) do
      schema = Validrb.schema do
        field :user, :object do
          field :profile, :object do
            field :settings, :object do
              field :theme, :string, enum: %w[light dark]
            end
          end
        end
      end
      result = schema.safe_parse(user: { profile: { settings: { theme: "invalid" } } })
      result.errors
    end

    it "formats deeply nested paths in standard format" do
      result = controller.format_errors(errors, :standard)

      field = result[:errors].first[:field]
      expect(field).to include(".")
      expect(field.split(".").length).to be >= 3
    end

    it "formats deeply nested paths in jsonapi format" do
      result = controller.format_errors(errors, :jsonapi)

      pointer = result[:errors].first[:source][:pointer]
      expect(pointer).to start_with("/data/attributes/")
      expect(pointer.split("/").length).to be >= 5
    end
  end

  describe "Array index errors" do
    let(:errors) do
      schema = Validrb.schema do
        field :items, :array do
          field :name, :string, min: 2
          field :price, :decimal, min: 0
        end
      end
      result = schema.safe_parse(items: [
        { name: "OK", price: "10" },
        { name: "X", price: "-5" },
        { name: "Y", price: "-10" }
      ])
      result.errors
    end

    it "includes array indices in standard format" do
      result = controller.format_errors(errors, :standard)

      fields = result[:errors].map { |e| e[:field] }
      expect(fields.any? { |f| f.match?(/items\.\d+/) }).to be true
    end

    it "includes array indices in jsonapi format" do
      result = controller.format_errors(errors, :jsonapi)

      pointers = result[:errors].map { |e| e[:source][:pointer] }
      expect(pointers.any? { |p| p.match?(/\/\d+\//) }).to be true
    end

    it "groups array errors by field in simple format" do
      result = controller.format_errors(errors, :simple)

      expect(result[:errors].keys.length).to be >= 2
    end
  end

  describe "Multiple errors on same field" do
    let(:errors) do
      schema = Validrb.schema do
        field :password, :string, refine: [
          { check: ->(v) { v.length >= 8 }, message: "must be at least 8 characters" },
          { check: ->(v) { v.match?(/[A-Z]/) }, message: "must contain uppercase" },
          { check: ->(v) { v.match?(/\d/) }, message: "must contain number" }
        ]
      end
      result = schema.safe_parse(password: "weak")
      result.errors
    end

    it "includes all errors in standard format" do
      result = controller.format_errors(errors, :standard)

      password_errors = result[:errors].select { |e| e[:field] == "password" }
      expect(password_errors.length).to be >= 2
    end

    it "groups multiple errors in simple format" do
      result = controller.format_errors(errors, :simple)

      expect(result[:errors]["password"].length).to be >= 2
    end
  end

  describe "Error codes" do
    let(:errors) do
      schema = Validrb.schema do
        field :email, :string, format: :email
        field :age, :integer, min: 0
      end
      result = schema.safe_parse(email: "invalid", age: -5)
      result.errors
    end

    it "includes error codes in standard format" do
      result = controller.format_errors(errors, :standard)

      result[:errors].each do |error|
        expect(error).to have_key(:code)
      end
    end

    it "includes error codes in jsonapi format" do
      result = controller.format_errors(errors, :jsonapi)

      result[:errors].each do |error|
        expect(error).to have_key(:code)
      end
    end
  end

  describe "Custom error format class attribute" do
    it "uses class-level default format" do
      custom_controller_class = Class.new do
        include Validrb::Rails::ApiErrorResponse
        self.validrb_error_format = :jsonapi

        attr_accessor :rendered_json, :rendered_status

        def render(json:, status:)
          @rendered_json = json
          @rendered_status = status
        end
      end

      controller = custom_controller_class.new
      schema = Validrb.schema { field :name, :string }
      result = schema.safe_parse(name: nil)

      controller.render_validation_errors(result.errors)

      expect(controller.rendered_json[:errors].first).to have_key(:source)
    end
  end

  describe "Empty errors" do
    it "handles empty error collection" do
      result = controller.format_errors([], :standard)

      expect(result[:errors]).to eq([])
    end
  end

  describe "Base errors (no path)" do
    let(:errors) do
      schema = Validrb.schema do
        field :start_date, :date
        field :end_date, :date

        validate do |data|
          if data[:start_date] && data[:end_date] && data[:start_date] > data[:end_date]
            error(:base, "end date must be after start date")
          end
        end
      end
      result = schema.safe_parse(start_date: "2024-12-31", end_date: "2024-01-01")
      result.errors
    end

    it "handles base errors in standard format" do
      result = controller.format_errors(errors, :standard)

      base_error = result[:errors].find { |e| e[:field] == "base" }
      expect(base_error).not_to be_nil
    end

    it "handles base errors in jsonapi format" do
      result = controller.format_errors(errors, :jsonapi)

      # Base errors have path [:base], which becomes /data/attributes/base
      base_error = result[:errors].find { |e| e[:source][:pointer].include?("base") }
      expect(base_error).not_to be_nil
    end
  end

  describe "HTTP status codes" do
    let(:errors) do
      schema = Validrb.schema { field :name, :string }
      schema.safe_parse(name: nil).errors
    end

    it "uses unprocessable_entity by default" do
      controller.render_validation_errors(errors)
      expect(controller.rendered_status).to eq(:unprocessable_entity)
    end

    it "allows custom status codes" do
      controller.render_validation_errors(errors, status: :bad_request)
      expect(controller.rendered_status).to eq(:bad_request)
    end

    it "accepts numeric status codes" do
      controller.render_validation_errors(errors, status: 400)
      expect(controller.rendered_status).to eq(400)
    end
  end

  describe "Detailed format metadata" do
    let(:errors) do
      schema = Validrb.schema do
        field :name, :string, min: 2
        field :email, :string, format: :email
      end
      schema.safe_parse(name: "J", email: "invalid").errors
    end

    it "includes error count in metadata" do
      result = controller.format_errors(errors, :detailed)

      expect(result[:meta][:count]).to eq(errors.to_a.length)
    end

    it "includes timestamp in metadata" do
      result = controller.format_errors(errors, :detailed)

      expect(result[:meta][:timestamp]).to match(/\d{4}-\d{2}-\d{2}/)
    end

    it "includes full messages" do
      result = controller.format_errors(errors, :detailed)

      result[:errors].each do |error|
        expect(error[:full_message]).to be_a(String)
        expect(error[:full_message].length).to be > error[:message].length
      end
    end

    it "includes path as array" do
      result = controller.format_errors(errors, :detailed)

      result[:errors].each do |error|
        expect(error[:path]).to be_an(Array)
      end
    end
  end

  describe "JSON serialization" do
    let(:errors) do
      schema = Validrb.schema do
        field :data, :object do
          field :items, :array do
            field :value, :integer, min: 0
          end
        end
      end
      schema.safe_parse(data: { items: [{ value: -1 }, { value: -2 }] }).errors
    end

    it "produces valid JSON for standard format" do
      result = controller.format_errors(errors, :standard)
      json = JSON.generate(result)
      parsed = JSON.parse(json)

      expect(parsed["errors"]).to be_an(Array)
    end

    it "produces valid JSON for jsonapi format" do
      result = controller.format_errors(errors, :jsonapi)
      json = JSON.generate(result)
      parsed = JSON.parse(json)

      expect(parsed["errors"]).to be_an(Array)
      expect(parsed["errors"].first["source"]["pointer"]).to be_a(String)
    end

    it "produces valid JSON for detailed format" do
      result = controller.format_errors(errors, :detailed)
      json = JSON.generate(result)
      parsed = JSON.parse(json)

      expect(parsed["meta"]["count"]).to be_an(Integer)
    end
  end

  describe "Integration with ValidationError" do
    it "extracts errors from ValidationError" do
      schema = Validrb.schema { field :name, :string }
      result = schema.safe_parse(name: nil)
      exception = Validrb::Rails::Controller::ValidationError.new(result)

      controller.render_validation_error(exception)

      expect(controller.rendered_json[:errors]).not_to be_empty
    end
  end

  describe "Unicode and special characters" do
    let(:errors) do
      schema = Validrb.schema do
        field :name, :string, min: 5
      end
      schema.safe_parse(name: "日本").errors
    end

    it "handles unicode in error messages" do
      result = controller.format_errors(errors, :standard)
      json = JSON.generate(result)

      expect { JSON.parse(json) }.not_to raise_error
    end
  end

  describe "Large error collections" do
    let(:errors) do
      fields = (1..50).map { |i| "field_#{i}" }
      schema = Validrb.schema do
        fields.each { |f| field f.to_sym, :string, min: 100 }
      end

      data = fields.each_with_object({}) { |f, h| h[f.to_sym] = "x" }
      schema.safe_parse(data).errors
    end

    it "handles many errors efficiently" do
      start_time = Time.now

      result = controller.format_errors(errors, :standard)

      elapsed = Time.now - start_time
      expect(elapsed).to be < 1.0
      expect(result[:errors].length).to eq(50)
    end
  end
end
