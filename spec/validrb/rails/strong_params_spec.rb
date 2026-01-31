# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe Validrb::Rails::StrongParams do
  # Simulate ActionController::Parameters with proper permit support
  let(:params_class) do
    Class.new(Hash) do
      def self.new_from_hash(hash)
        instance = new
        hash.each { |k, v| instance[k] = v.is_a?(Hash) ? new_from_hash(v) : v }
        instance
      end

      def require(key)
        value = self[key] || self[key.to_s]
        raise KeyError, "param is missing: #{key}" unless value
        value.is_a?(Hash) ? self.class.new_from_hash(value) : value
      end

      def permit(*keys)
        permitted = self.class.new
        flatten_keys(keys).each do |key|
          case key
          when Symbol, String
            permitted[key] = self[key] if key?(key) || key?(key.to_s)
          when Hash
            key.each do |k, v|
              if key?(k) || key?(k.to_s)
                val = self[k] || self[k.to_s]
                permitted[k] = val.is_a?(Hash) ? self.class.new_from_hash(val) : val
              end
            end
          end
        end
        permitted
      end

      def to_h
        result = {}
        each { |k, v| result[k] = v.is_a?(self.class) ? v.to_h : v }
        result
      end

      private

      def flatten_keys(keys)
        keys.flat_map { |k| k.is_a?(Array) ? flatten_keys(k) : k }
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

  describe "#permitted_params" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
        field :email, :string
        field :age, :integer
      end
    end

    it "returns permitted params based on schema" do
      controller = controller_class.new(
        { user: { name: "John", email: "john@example.com", age: 30, admin: true } },
        mock_request
      )

      result = controller.permitted_params(schema, :user)
      expect(result).to include(:name, :email, :age)
      expect(result).not_to include(:admin)
    end

    it "works without nested key" do
      controller = controller_class.new(
        { name: "John", email: "john@example.com" },
        mock_request
      )

      result = controller.permitted_params(schema)
      expect(result).to include(:name, :email)
    end
  end

  describe "#validated_params" do
    let(:schema) do
      Validrb.schema do
        field :name, :string, min: 2
        field :email, :string, format: :email
      end
    end

    it "returns success result for valid params" do
      controller = controller_class.new(
        { user: { name: "John", email: "john@example.com" } },
        mock_request
      )

      result = controller.validated_params(schema, :user)
      expect(result).to be_success
      expect(result.data[:name]).to eq("John")
    end

    it "returns failure result for invalid params" do
      controller = controller_class.new(
        { user: { name: "J", email: "invalid" } },
        mock_request
      )

      result = controller.validated_params(schema, :user)
      expect(result).to be_failure
    end
  end

  describe "#validated_params!" do
    let(:schema) do
      Validrb.schema do
        field :name, :string, min: 2
      end
    end

    it "returns data for valid params" do
      controller = controller_class.new(
        { name: "John" },
        mock_request
      )

      data = controller.validated_params!(schema)
      expect(data[:name]).to eq("John")
    end

    it "raises for invalid params" do
      controller = controller_class.new(
        { name: "J" },
        mock_request
      )

      expect {
        controller.validated_params!(schema)
      }.to raise_error(Validrb::Rails::Controller::ValidationError)
    end
  end

  describe "nested schema permit list" do
    let(:schema) do
      Validrb.schema do
        field :name, :string
        field :address, :object do
          field :street, :string
          field :city, :string
        end
        field :tags, :array, of: :string
      end
    end

    it "handles nested objects in permit list" do
      controller = controller_class.new(
        {
          user: {
            name: "John",
            address: { street: "123 Main", city: "NYC" },
            tags: %w[ruby rails]
          }
        },
        mock_request
      )

      result = controller.permitted_params(schema, :user)
      expect(result[:name]).to eq("John")
    end
  end

  describe "#build_permit_list" do
    let(:controller) { controller_class.new({}, mock_request) }

    it "returns field names for simple schema" do
      schema = Validrb.schema do
        field :name, :string
        field :age, :integer
      end

      permit_list = controller.send(:build_permit_list, schema)
      expect(permit_list).to include(:name, :age)
    end

    it "returns nested hash for object fields" do
      schema = Validrb.schema do
        field :address, :object do
          field :street, :string
          field :city, :string
        end
      end

      permit_list = controller.send(:build_permit_list, schema)
      expect(permit_list.first).to be_a(Hash)
      expect(permit_list.first).to have_key(:address)
    end

    it "returns array hash for array fields" do
      schema = Validrb.schema do
        field :tags, :array, of: :string
      end

      permit_list = controller.send(:build_permit_list, schema)
      expect(permit_list.first).to be_a(Hash)
      expect(permit_list.first).to have_key(:tags)
    end
  end
end
