# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe Validrb::Rails::Controller do
  # Mock request object
  let(:mock_request) { double("request") }

  # Mock controller class
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

  let(:user_schema) do
    Validrb.schema do
      field :name, :string, min: 2
      field :email, :string, format: :email
      field :age, :integer, optional: true
    end
  end

  describe "#validate_params" do
    it "validates params against schema" do
      controller = controller_class.new(
        { user: { name: "John", email: "john@example.com" } },
        mock_request
      )

      result = controller.validate_params(user_schema, :user)

      expect(result).to be_success
      expect(result.data[:name]).to eq("John")
    end

    it "returns failure for invalid params" do
      controller = controller_class.new(
        { user: { name: "J", email: "invalid" } },
        mock_request
      )

      result = controller.validate_params(user_schema, :user)

      expect(result).to be_failure
      expect(result.errors).not_to be_empty
    end

    it "validates root params when no key given" do
      controller = controller_class.new(
        { name: "John", email: "john@example.com" },
        mock_request
      )

      result = controller.validate_params(user_schema)

      expect(result).to be_success
    end

    it "coerces types" do
      controller = controller_class.new(
        { user: { name: "John", email: "john@example.com", age: "30" } },
        mock_request
      )

      result = controller.validate_params(user_schema, :user)

      expect(result.data[:age]).to eq(30)
    end

    context "with context" do
      let(:context_schema) do
        Validrb.schema do
          field :amount, :integer,
                refine: ->(v, ctx) { !ctx || !ctx[:max_amount] || v <= ctx[:max_amount] },
                message: "exceeds maximum"
        end
      end

      it "passes context to schema" do
        controller = controller_class.new({ amount: 100 }, mock_request)

        result = controller.validate_params(context_schema, context: { max_amount: 50 })

        expect(result).to be_failure
      end

      it "includes current_user in default context" do
        controller = controller_class.new({ amount: 100 }, mock_request)
        controller.current_user = double("user", id: 1)

        # The context building happens internally
        result = controller.validate_params(context_schema)

        # This should pass because no max_amount constraint in default context
        expect(result).to be_success
      end
    end
  end

  describe "#validate_params!" do
    it "returns data for valid params" do
      controller = controller_class.new(
        { user: { name: "John", email: "john@example.com" } },
        mock_request
      )

      data = controller.validate_params!(user_schema, :user)

      expect(data[:name]).to eq("John")
    end

    it "raises ValidationError for invalid params" do
      controller = controller_class.new(
        { user: { name: "J", email: "invalid" } },
        mock_request
      )

      expect {
        controller.validate_params!(user_schema, :user)
      }.to raise_error(Validrb::Rails::Controller::ValidationError)
    end

    it "includes errors in exception" do
      controller = controller_class.new(
        { user: { name: "J", email: "invalid" } },
        mock_request
      )

      begin
        controller.validate_params!(user_schema, :user)
      rescue Validrb::Rails::Controller::ValidationError => e
        expect(e.errors).not_to be_empty
        expect(e.result).to be_a(Validrb::Failure)
      end
    end
  end

  describe "#build_form" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "TestForm"
        end

        schema do
          field :title, :string
        end
      end
    end

    it "creates form object with params" do
      controller = controller_class.new(
        { post: { title: "Hello World" } },
        mock_request
      )

      form = controller.build_form(form_class, :post)

      expect(form).to be_a(Validrb::Rails::FormObject)
      expect(form.title).to eq("Hello World")
    end

    it "creates form with root params" do
      controller = controller_class.new({ title: "Hello World" }, mock_request)

      form = controller.build_form(form_class)

      expect(form.title).to eq("Hello World")
    end
  end
end
