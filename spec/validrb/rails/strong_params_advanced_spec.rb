# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "StrongParams Advanced Features" do
  # Enhanced ActionController::Parameters simulation
  let(:params_class) do
    Class.new(Hash) do
      def self.new_from_hash(hash)
        instance = new
        hash.each do |k, v|
          instance[k] = case v
                        when Hash then new_from_hash(v)
                        when Array then v.map { |item| item.is_a?(Hash) ? new_from_hash(item) : item }
                        else v
                        end
        end
        instance
      end

      def require(key)
        value = self[key] || self[key.to_s]
        raise KeyError, "param is missing: #{key}" unless value
        value.is_a?(Hash) ? self.class.new_from_hash(value) : value
      end

      def permit(*keys)
        permitted = self.class.new
        process_permit_keys(keys, permitted)
        permitted
      end

      def to_h
        result = {}
        each { |k, v| result[k] = v.is_a?(self.class) ? v.to_h : v }
        result
      end

      private

      def process_permit_keys(keys, permitted)
        keys.flatten.each do |key|
          case key
          when Symbol, String
            permitted[key] = self[key] if key?(key) || key?(key.to_s)
          when Hash
            key.each do |k, v|
              val = self[k] || self[k.to_s]
              next unless val
              permitted[k] = process_nested_permit(val, v)
            end
          end
        end
      end

      def process_nested_permit(value, permit_spec)
        case value
        when Hash
          nested = self.class.new_from_hash(value)
          nested.permit(*Array(permit_spec))
        when Array
          value.map do |item|
            if item.is_a?(Hash)
              nested = self.class.new_from_hash(item)
              nested.permit(*Array(permit_spec))
            else
              item
            end
          end
        else
          value
        end
      end
    end
  end

  let(:controller_class) do
    pc = params_class
    Class.new do
      include Validrb::Rails::Controller
      include Validrb::Rails::StrongParams

      attr_accessor :params, :request, :current_user

      define_method(:params_class) { pc }

      def initialize(params = {}, request = nil)
        @params = params_class.new_from_hash(params)
        @request = request
        @current_user = nil
      end
    end
  end

  let(:mock_request) { double("request", present?: true) }

  describe "Complex nested schemas" do
    let(:order_schema) do
      Validrb.schema do
        field :customer, :object do
          field :name, :string
          field :email, :string, format: :email
          field :address, :object do
            field :street, :string
            field :city, :string
            field :zip, :string
          end
        end
        field :items, :array do
          field :product_id, :integer
          field :quantity, :integer
          field :options, :object, optional: true do
            field :color, :string
            field :size, :string
          end
        end
        field :payment, :object do
          field :method, :string
          field :card_last_four, :string, optional: true
        end
      end
    end

    it "permits deeply nested params" do
      controller = controller_class.new({
        order: {
          customer: {
            name: "John",
            email: "john@example.com",
            address: { street: "123 Main", city: "NYC", zip: "10001" },
            ssn: "secret"  # Should be filtered
          },
          items: [
            { product_id: 1, quantity: 2, options: { color: "red", size: "L" } },
            { product_id: 2, quantity: 1 }
          ],
          payment: { method: "card", card_last_four: "1234" },
          internal_notes: "filtered"  # Should be filtered
        }
      }, mock_request)

      result = controller.permitted_params(order_schema, :order)
      expect(result[:customer][:name]).to eq("John")
      expect(result[:customer][:address][:city]).to eq("NYC")
      expect(result[:items].first[:product_id]).to eq(1)
    end

    it "validates deeply nested params" do
      controller = controller_class.new({
        order: {
          customer: {
            name: "John",
            email: "invalid-email",
            address: { street: "123 Main", city: "NYC", zip: "10001" }
          },
          items: [{ product_id: 1, quantity: 2 }],
          payment: { method: "card" }
        }
      }, mock_request)

      result = controller.validated_params(order_schema, :order)
      expect(result).to be_failure
      expect(result.errors.to_a.any? { |e| e.path.include?(:email) }).to be true
    end
  end

  describe "Array of primitives" do
    let(:schema) do
      Validrb.schema do
        field :tags, :array, of: :string
        field :scores, :array, of: :integer
        field :flags, :array, of: :boolean
      end
    end

    it "permits arrays of primitives" do
      controller = controller_class.new({
        tags: %w[ruby rails web],
        scores: [85, 90, 95],
        flags: [true, false, true]
      }, mock_request)

      result = controller.permitted_params(schema)
      expect(result[:tags]).to eq(%w[ruby rails web])
      expect(result[:scores]).to eq([85, 90, 95])
    end

    it "coerces array items" do
      controller = controller_class.new({
        tags: [:ruby, :rails],
        scores: %w[85 90 95],
        flags: %w[true false yes]
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
      expect(result.data[:scores]).to eq([85, 90, 95])
      expect(result.data[:flags]).to eq([true, false, true])
    end
  end

  describe "Optional and nullable fields" do
    let(:schema) do
      Validrb.schema do
        field :required_field, :string
        field :optional_field, :string, optional: true
        field :nullable_field, :string, nullable: true, optional: true
        field :default_field, :string, default: "default_value"
      end
    end

    it "handles missing optional fields" do
      controller = controller_class.new({
        required_field: "value"
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
      expect(result.data[:default_field]).to eq("default_value")
    end

    it "handles null values for nullable fields" do
      controller = controller_class.new({
        required_field: "value",
        nullable_field: nil
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
      expect(result.data[:nullable_field]).to be_nil
    end
  end

  describe "Discriminated unions" do
    let(:card_schema) do
      Validrb.schema do
        field :type, :string, literal: ["card"]
        field :number, :string
        field :cvv, :string
      end
    end

    let(:bank_schema) do
      Validrb.schema do
        field :type, :string, literal: ["bank"]
        field :account_number, :string
        field :routing_number, :string
      end
    end

    let(:schema) do
      card = card_schema
      bank = bank_schema
      Validrb.schema do
        field :amount, :decimal
        field :payment, :discriminated_union,
              discriminator: :type,
              mapping: { "card" => card, "bank" => bank }
      end
    end

    it "validates card payment" do
      controller = controller_class.new({
        amount: "99.99",
        payment: { type: "card", number: "4111111111111111", cvv: "123" }
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
      expect(result.data[:payment][:type]).to eq("card")
    end

    it "validates bank payment" do
      controller = controller_class.new({
        amount: "99.99",
        payment: { type: "bank", account_number: "123456789", routing_number: "021000021" }
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
      expect(result.data[:payment][:type]).to eq("bank")
    end

    it "fails for invalid discriminator" do
      controller = controller_class.new({
        amount: "99.99",
        payment: { type: "crypto", wallet: "abc123" }
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_failure
    end
  end

  describe "Context passing" do
    let(:schema) do
      Validrb.schema do
        field :amount, :decimal

        validate do |data, ctx|
          if ctx && ctx[:max_amount] && data[:amount] > ctx[:max_amount]
            error(:amount, "exceeds maximum allowed")
          end
        end
      end
    end

    it "passes context to validation" do
      controller = controller_class.new({ amount: "1000" }, mock_request)

      result = controller.validated_params(schema, context: { max_amount: 500 })
      expect(result).to be_failure
      expect(result.errors.to_a.first.message).to include("exceeds")
    end

    it "passes without context violation" do
      controller = controller_class.new({ amount: "100" }, mock_request)

      result = controller.validated_params(schema, context: { max_amount: 500 })
      expect(result).to be_success
    end
  end

  describe "Missing required params" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
        field :email, :string
      end
    end

    it "raises KeyError for missing required key" do
      controller = controller_class.new({ other: "value" }, mock_request)

      expect {
        controller.permitted_params(schema, :user)
      }.to raise_error(KeyError)
    end
  end

  describe "Transforms and preprocessing" do
    let(:schema) do
      Validrb.schema do
        field :email, :string,
              preprocess: ->(v) { v&.strip&.downcase },
              format: :email
        field :tags, :string,
              transform: ->(v) { v.split(",").map(&:strip) }
      end
    end

    it "applies preprocessing" do
      controller = controller_class.new({
        email: "  JOHN@EXAMPLE.COM  ",
        tags: "ruby, rails, web"
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
      expect(result.data[:email]).to eq("john@example.com")
      expect(result.data[:tags]).to eq(%w[ruby rails web])
    end
  end

  describe "Concurrent usage" do
    let(:schema) do
      Validrb.schema do
        field :id, :integer
        field :value, :string
      end
    end

    it "handles concurrent validated_params calls" do
      results = []
      mutex = Mutex.new

      threads = 20.times.map do |i|
        Thread.new do
          controller = controller_class.new({ id: i.to_s, value: "value_#{i}" }, mock_request)
          result = controller.validated_params(schema)
          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(20)
      expect(results.all?(&:success?)).to be true
      ids = results.map { |r| r.data[:id] }.sort
      expect(ids).to eq((0..19).to_a)
    end
  end

  describe "Strict mode schema" do
    let(:schema) do
      Validrb.schema(strict: true) do
        field :name, :string
        field :email, :string
      end
    end

    # Note: validated_params first permits params based on schema,
    # so unknown fields are filtered before validation
    it "accepts known params" do
      controller = controller_class.new({
        name: "John",
        email: "john@example.com"
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
    end

    it "strict mode works on direct schema parse" do
      # When parsing directly without permit filtering,
      # strict mode rejects unknown keys
      result = schema.safe_parse(
        name: "John",
        email: "john@example.com",
        admin: true
      )
      expect(result).to be_failure
    end
  end

  describe "Passthrough mode schema" do
    let(:schema) do
      Validrb.schema(passthrough: true) do
        field :name, :string
      end
    end

    # Note: validated_params uses permitted_params which only permits
    # known fields. Passthrough mode applies to direct schema parsing.
    it "validates permitted params" do
      controller = controller_class.new({
        name: "John",
        extra: "value"
      }, mock_request)

      result = controller.validated_params(schema)
      expect(result).to be_success
      expect(result.data[:name]).to eq("John")
    end

    it "passthrough mode keeps unknown params on direct parse" do
      # When parsing directly without permit filtering,
      # passthrough mode keeps unknown keys
      result = schema.safe_parse(
        name: "John",
        extra: "value",
        metadata: { key: "value" }
      )
      expect(result).to be_success
      expect(result.data[:extra]).to eq("value")
    end
  end
end
