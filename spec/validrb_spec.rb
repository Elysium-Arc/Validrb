# frozen_string_literal: true

require "spec_helper"

RSpec.describe Validrb do
  it "has a version number" do
    expect(Validrb::VERSION).not_to be_nil
    expect(Validrb::VERSION).to eq("0.5.0")
  end

  describe ".schema" do
    it "creates a schema with a block" do
      schema = Validrb.schema do
        field :name, :string
      end

      expect(schema).to be_a(Validrb::Schema)
      expect(schema.fields).to have_key(:name)
    end

    it "creates an empty schema without a block" do
      schema = Validrb.schema {}
      expect(schema.fields).to be_empty
    end
  end
end
