# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb::Types::DiscriminatedUnion do
  let(:dog_schema) do
    Validrb.schema do
      field :type, :string
      field :breed, :string
      field :barks, :boolean, default: true
    end
  end

  let(:cat_schema) do
    Validrb.schema do
      field :type, :string
      field :color, :string
      field :meows, :boolean, default: true
    end
  end

  let(:type) do
    described_class.new(
      discriminator: :type,
      mapping: {
        "dog" => dog_schema,
        "cat" => cat_schema
      }
    )
  end

  describe "#call" do
    it "selects dog schema when type is dog" do
      value, errors = type.call({ type: "dog", breed: "labrador" })
      expect(errors).to be_empty
      expect(value[:type]).to eq("dog")
      expect(value[:breed]).to eq("labrador")
      expect(value[:barks]).to be true
    end

    it "selects cat schema when type is cat" do
      value, errors = type.call({ type: "cat", color: "orange" })
      expect(errors).to be_empty
      expect(value[:type]).to eq("cat")
      expect(value[:color]).to eq("orange")
      expect(value[:meows]).to be true
    end

    it "fails when discriminator is missing" do
      value, errors = type.call({ breed: "labrador" })
      expect(value).to be_nil
      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:discriminator_missing)
    end

    it "fails when discriminator value is invalid" do
      value, errors = type.call({ type: "bird", wings: 2 })
      expect(value).to be_nil
      expect(errors.size).to eq(1)
      expect(errors.first.code).to eq(:invalid_discriminator)
    end

    it "validates using selected schema rules" do
      # Missing required field for dog schema
      value, errors = type.call({ type: "dog" })
      expect(value).to be_nil
      expect(errors.any? { |e| e.path == [:breed] }).to be true
    end

    it "works with string keys" do
      value, errors = type.call({ "type" => "cat", "color" => "black" })
      expect(errors).to be_empty
      expect(value[:type]).to eq("cat")
    end
  end

  describe "#type_name" do
    it "shows discriminator and options" do
      expect(type.type_name).to include("discriminated_union")
      expect(type.type_name).to include("type")
    end
  end

  describe "registry" do
    it "is registered as :discriminated_union" do
      expect(Validrb::Types.lookup(:discriminated_union)).to eq(described_class)
    end
  end
end
