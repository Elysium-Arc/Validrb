# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Validrb::Field do
  describe '#initialize' do
    it 'creates a field with name and type' do
      field = described_class.new(:name, :string)

      expect(field.name).to eq(:name)
      expect(field.type).to be_a(Validrb::Types::String)
    end

    it 'normalizes string name to symbol' do
      field = described_class.new('name', :string)

      expect(field.name).to eq(:name)
    end

    it 'freezes the field' do
      field = described_class.new(:name, :string)

      expect(field).to be_frozen
    end
  end

  describe '#optional?' do
    it 'returns false by default' do
      field = described_class.new(:name, :string)

      expect(field.optional?).to be false
    end

    it 'returns true when optional: true' do
      field = described_class.new(:name, :string, optional: true)

      expect(field.optional?).to be true
    end
  end

  describe '#required?' do
    it 'returns true by default' do
      field = described_class.new(:name, :string)

      expect(field.required?).to be true
    end

    it 'returns false when optional' do
      field = described_class.new(:name, :string, optional: true)

      expect(field.required?).to be false
    end
  end

  describe '#has_default?' do
    it 'returns false when no default' do
      field = described_class.new(:name, :string)

      expect(field.has_default?).to be false
    end

    it 'returns true when default is set' do
      field = described_class.new(:name, :string, default: 'John')

      expect(field.has_default?).to be true
    end

    it 'returns true when default is nil' do
      field = described_class.new(:name, :string, default: nil)

      expect(field.has_default?).to be true
    end
  end

  describe '#default_value' do
    it 'returns the default value' do
      field = described_class.new(:name, :string, default: 'John')

      expect(field.default_value).to eq('John')
    end

    it 'calls proc default' do
      counter = 0
      field = described_class.new(:id, :integer, default: -> { counter += 1 })

      expect(field.default_value).to eq(1)
      expect(field.default_value).to eq(2)
    end
  end

  describe '#call' do
    context 'with valid value' do
      it 'returns coerced value and empty errors' do
        field = described_class.new(:age, :integer)
        value, errors = field.call('42')

        expect(value).to eq(42)
        expect(errors).to be_empty
      end
    end

    context 'with missing value' do
      it 'returns error for required field' do
        field = described_class.new(:name, :string)
        value, errors = field.call(Validrb::Field::MISSING)

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq('is required')
        expect(errors.first.code).to eq(:required)
      end

      it 'returns nil for optional field' do
        field = described_class.new(:name, :string, optional: true)
        value, errors = field.call(Validrb::Field::MISSING)

        expect(value).to be_nil
        expect(errors).to be_empty
      end

      it 'returns default value when set' do
        field = described_class.new(:role, :string, default: 'user')
        value, errors = field.call(Validrb::Field::MISSING)

        expect(value).to eq('user')
        expect(errors).to be_empty
      end
    end

    context 'with nil value' do
      it 'treats nil same as missing for required field' do
        field = described_class.new(:name, :string)
        value, errors = field.call(nil)

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:required)
      end

      it 'returns nil for optional field' do
        field = described_class.new(:name, :string, optional: true)
        value, errors = field.call(nil)

        expect(value).to be_nil
        expect(errors).to be_empty
      end
    end

    context 'with type error' do
      it 'returns type error' do
        field = described_class.new(:age, :integer)
        value, errors = field.call('not a number')

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:type_error)
      end
    end

    context 'with constraint errors' do
      it 'validates min constraint' do
        field = described_class.new(:age, :integer, min: 18)
        value, errors = field.call(15)

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:min)
      end

      it 'validates max constraint' do
        field = described_class.new(:age, :integer, max: 120)
        value, errors = field.call(150)

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:max)
      end

      it 'validates format constraint' do
        field = described_class.new(:email, :string, format: :email)
        value, errors = field.call('not-an-email')

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:format)
      end

      it 'validates enum constraint' do
        field = described_class.new(:role, :string, enum: %w[admin user])
        value, errors = field.call('guest')

        expect(value).to be_nil
        expect(errors.size).to eq(1)
        expect(errors.first.code).to eq(:enum)
      end
    end

    context 'with path' do
      it 'includes path in errors' do
        field = described_class.new(:name, :string)
        _value, errors = field.call(Validrb::Field::MISSING, path: [:user])

        expect(errors.first.path).to eq(%i[user name])
      end
    end
  end

  describe 'constraints' do
    it 'builds min constraint' do
      field = described_class.new(:name, :string, min: 3)

      expect(field.constraints.size).to eq(1)
      expect(field.constraints.first).to be_a(Validrb::Constraints::Min)
    end

    it 'builds max constraint' do
      field = described_class.new(:name, :string, max: 100)

      expect(field.constraints.size).to eq(1)
      expect(field.constraints.first).to be_a(Validrb::Constraints::Max)
    end

    it 'builds length constraint from integer' do
      field = described_class.new(:code, :string, length: 6)

      expect(field.constraints.size).to eq(1)
      expect(field.constraints.first).to be_a(Validrb::Constraints::Length)
    end

    it 'builds length constraint from range' do
      field = described_class.new(:code, :string, length: 4..8)

      expect(field.constraints.size).to eq(1)
      expect(field.constraints.first).to be_a(Validrb::Constraints::Length)
    end

    it 'builds length constraint from hash' do
      field = described_class.new(:code, :string, length: { min: 4, max: 8 })

      expect(field.constraints.size).to eq(1)
      expect(field.constraints.first).to be_a(Validrb::Constraints::Length)
    end

    it 'builds format constraint' do
      field = described_class.new(:email, :string, format: :email)

      expect(field.constraints.size).to eq(1)
      expect(field.constraints.first).to be_a(Validrb::Constraints::Format)
    end

    it 'builds enum constraint' do
      field = described_class.new(:role, :string, enum: %w[admin user])

      expect(field.constraints.size).to eq(1)
      expect(field.constraints.first).to be_a(Validrb::Constraints::Enum)
    end

    it 'builds multiple constraints' do
      field = described_class.new(:name, :string, min: 1, max: 100, format: /\A[A-Z]/)

      expect(field.constraints.size).to eq(3)
    end
  end
end
