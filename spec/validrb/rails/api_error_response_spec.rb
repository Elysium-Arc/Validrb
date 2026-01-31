# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe Validrb::Rails::ApiErrorResponse do
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

  let(:errors) do
    schema = Validrb.schema do
      field :email, :string, format: :email
      field :name, :string, min: 2
    end
    result = schema.safe_parse(email: "invalid", name: "J")
    result.errors
  end

  describe "#format_errors" do
    describe ":standard format" do
      it "returns standard error format" do
        result = controller.format_errors(errors, :standard)

        expect(result).to have_key(:errors)
        expect(result[:errors]).to be_an(Array)
        expect(result[:errors].first).to have_key(:field)
        expect(result[:errors].first).to have_key(:message)
      end

      it "formats field paths correctly" do
        result = controller.format_errors(errors, :standard)

        fields = result[:errors].map { |e| e[:field] }
        expect(fields).to include("email", "name")
      end
    end

    describe ":jsonapi format" do
      it "returns JSON:API compliant format" do
        result = controller.format_errors(errors, :jsonapi)

        expect(result).to have_key(:errors)
        expect(result[:errors].first).to have_key(:source)
        expect(result[:errors].first[:source]).to have_key(:pointer)
        expect(result[:errors].first).to have_key(:detail)
      end

      it "formats pointers correctly" do
        result = controller.format_errors(errors, :jsonapi)

        pointers = result[:errors].map { |e| e[:source][:pointer] }
        expect(pointers).to all(start_with("/data/attributes/"))
      end
    end

    describe ":simple format" do
      it "returns grouped errors by field" do
        result = controller.format_errors(errors, :simple)

        expect(result).to have_key(:errors)
        expect(result[:errors]).to be_a(Hash)
        expect(result[:errors]["email"]).to be_an(Array)
        expect(result[:errors]["name"]).to be_an(Array)
      end
    end

    describe ":detailed format" do
      it "returns detailed error information" do
        result = controller.format_errors(errors, :detailed)

        expect(result).to have_key(:errors)
        expect(result).to have_key(:meta)
        expect(result[:errors].first).to have_key(:path)
        expect(result[:errors].first).to have_key(:full_message)
        expect(result[:meta]).to have_key(:count)
        expect(result[:meta]).to have_key(:timestamp)
      end
    end
  end

  describe "#render_validation_errors" do
    it "renders errors with default status" do
      controller.render_validation_errors(errors)

      expect(controller.rendered_status).to eq(:unprocessable_entity)
      expect(controller.rendered_json).to have_key(:errors)
    end

    it "renders with custom status" do
      controller.render_validation_errors(errors, status: :bad_request)

      expect(controller.rendered_status).to eq(:bad_request)
    end

    it "renders with specified format" do
      controller.render_validation_errors(errors, format: :jsonapi)

      expect(controller.rendered_json[:errors].first).to have_key(:source)
    end
  end

  describe "#render_validation_error" do
    it "handles ValidationError exception" do
      schema = Validrb.schema { field :name, :string }
      result = schema.safe_parse(name: nil)
      exception = Validrb::Rails::Controller::ValidationError.new(result)

      controller.render_validation_error(exception)

      expect(controller.rendered_json).to have_key(:errors)
      expect(controller.rendered_status).to eq(:unprocessable_entity)
    end
  end

  describe "nested error paths" do
    let(:nested_errors) do
      schema = Validrb.schema do
        field :user, :object do
          field :profile, :object do
            field :bio, :string, min: 10
          end
        end
      end
      result = schema.safe_parse(user: { profile: { bio: "short" } })
      result.errors
    end

    it "formats nested paths in standard format" do
      result = controller.format_errors(nested_errors, :standard)

      fields = result[:errors].map { |e| e[:field] }
      expect(fields.first).to include(".")
    end

    it "formats nested paths in jsonapi format" do
      result = controller.format_errors(nested_errors, :jsonapi)

      pointers = result[:errors].map { |e| e[:source][:pointer] }
      expect(pointers.first).to include("/")
    end
  end

  describe "array index paths" do
    let(:array_errors) do
      schema = Validrb.schema do
        field :items, :array do
          field :name, :string, min: 2
        end
      end
      result = schema.safe_parse(items: [{ name: "OK" }, { name: "X" }])
      result.errors
    end

    it "includes array indices in paths" do
      result = controller.format_errors(array_errors, :standard)

      fields = result[:errors].map { |e| e[:field] }
      expect(fields.any? { |f| f.match?(/\d/) }).to be true
    end
  end
end

RSpec.describe Validrb::Rails::ApiErrorHandler do
  # This tests the combined module that sets up rescue_from
  let(:api_controller_class) do
    Class.new do
      # Simulate rescue_from behavior
      class << self
        attr_accessor :rescue_handlers

        def rescue_from(exception_class, &block)
          @rescue_handlers ||= {}
          @rescue_handlers[exception_class] = block
        end
      end

      include Validrb::Rails::ApiErrorHandler

      attr_accessor :rendered_json, :rendered_status

      def render(json:, status:)
        @rendered_json = json
        @rendered_status = status
      end

      def handle_exception(exception)
        handler = self.class.rescue_handlers[exception.class]
        instance_exec(exception, &handler) if handler
      end
    end
  end

  it "sets up rescue handlers" do
    expect(api_controller_class.rescue_handlers).to have_key(Validrb::Rails::Controller::ValidationError)
  end

  it "handles validation errors through rescue" do
    controller = api_controller_class.new
    schema = Validrb.schema { field :name, :string }
    result = schema.safe_parse(name: nil)
    exception = Validrb::Rails::Controller::ValidationError.new(result)

    controller.handle_exception(exception)

    expect(controller.rendered_json).to have_key(:errors)
  end
end
