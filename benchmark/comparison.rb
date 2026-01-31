#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark comparing Validrb vs dry-validation
#
# Run with: bundle exec ruby benchmark/comparison.rb

require "bundler/setup"
require "benchmark/ips"
require "validrb"
require "dry-validation"

puts "=" * 70
puts "Validrb vs dry-validation Performance Comparison"
puts "=" * 70
puts

# ==============================================================================
# Simple Schema Benchmark
# ==============================================================================

puts "-" * 70
puts "1. Simple Schema (3 fields)"
puts "-" * 70

# Validrb schema
validrb_simple = Validrb.schema do
  field :name, :string, min: 2, max: 100
  field :email, :string, format: :email
  field :age, :integer, min: 0, max: 150
end

# dry-validation contract
class DrySimpleContract < Dry::Validation::Contract
  params do
    required(:name).filled(:string, min_size?: 2, max_size?: 100)
    required(:email).filled(:string, format?: /@/)
    required(:age).filled(:integer, gteq?: 0, lteq?: 150)
  end
end
dry_simple = DrySimpleContract.new

valid_simple_data = { name: "John Doe", email: "john@example.com", age: 30 }
invalid_simple_data = { name: "J", email: "invalid", age: -5 }

puts "\nValid data:"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_simple.safe_parse(valid_simple_data) }
  x.report("dry-validation") { dry_simple.call(valid_simple_data) }

  x.compare!
end

puts "\nInvalid data:"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_simple.safe_parse(invalid_simple_data) }
  x.report("dry-validation") { dry_simple.call(invalid_simple_data) }

  x.compare!
end

# ==============================================================================
# Nested Schema Benchmark
# ==============================================================================

puts "\n" + "-" * 70
puts "2. Nested Schema (user with address)"
puts "-" * 70

# Validrb nested schema
validrb_nested = Validrb.schema do
  field :name, :string, min: 2
  field :email, :string, format: :email
  field :address, :object do
    field :street, :string, min: 1
    field :city, :string, min: 1
    field :state, :string, length: 2
    field :zip, :string, format: /\A\d{5}\z/
  end
end

# dry-validation nested contract
class DryNestedContract < Dry::Validation::Contract
  params do
    required(:name).filled(:string, min_size?: 2)
    required(:email).filled(:string, format?: /@/)
    required(:address).hash do
      required(:street).filled(:string, min_size?: 1)
      required(:city).filled(:string, min_size?: 1)
      required(:state).filled(:string, size?: 2)
      required(:zip).filled(:string, format?: /\A\d{5}\z/)
    end
  end
end
dry_nested = DryNestedContract.new

valid_nested_data = {
  name: "John Doe",
  email: "john@example.com",
  address: {
    street: "123 Main St",
    city: "New York",
    state: "NY",
    zip: "10001"
  }
}

puts "\nValid data:"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_nested.safe_parse(valid_nested_data) }
  x.report("dry-validation") { dry_nested.call(valid_nested_data) }

  x.compare!
end

# ==============================================================================
# Array Schema Benchmark
# ==============================================================================

puts "\n" + "-" * 70
puts "3. Array Schema (10 items)"
puts "-" * 70

# Validrb array schema
validrb_array = Validrb.schema do
  field :items, :array do
    field :name, :string, min: 1
    field :price, :float, min: 0
    field :quantity, :integer, min: 1
  end
end

# dry-validation array contract
class DryArrayContract < Dry::Validation::Contract
  params do
    required(:items).array(:hash) do
      required(:name).filled(:string, min_size?: 1)
      required(:price).filled(:float, gteq?: 0)
      required(:quantity).filled(:integer, gteq?: 1)
    end
  end
end
dry_array = DryArrayContract.new

valid_array_data = {
  items: 10.times.map do |i|
    { name: "Item #{i}", price: 9.99 + i, quantity: i + 1 }
  end
}

puts "\nValid data (10 items):"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_array.safe_parse(valid_array_data) }
  x.report("dry-validation") { dry_array.call(valid_array_data) }

  x.compare!
end

# ==============================================================================
# Large Array Benchmark
# ==============================================================================

puts "\n" + "-" * 70
puts "4. Large Array (100 items)"
puts "-" * 70

valid_large_array_data = {
  items: 100.times.map do |i|
    { name: "Item #{i}", price: 9.99 + i, quantity: i + 1 }
  end
}

puts "\nValid data (100 items):"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_array.safe_parse(valid_large_array_data) }
  x.report("dry-validation") { dry_array.call(valid_large_array_data) }

  x.compare!
end

# ==============================================================================
# Type Coercion Benchmark
# ==============================================================================

puts "\n" + "-" * 70
puts "5. Type Coercion (strings to typed values)"
puts "-" * 70

# Validrb coercion schema
validrb_coerce = Validrb.schema do
  field :count, :integer
  field :price, :float
  field :active, :boolean
  field :date, :date
  field :amount, :decimal
end

# dry-validation with coercion
class DryCoerceContract < Dry::Validation::Contract
  params do
    required(:count).filled(:integer)
    required(:price).filled(:float)
    required(:active).filled(:bool)
    required(:date).filled(:date)
    required(:amount).filled(:decimal)
  end
end
dry_coerce = DryCoerceContract.new

coerce_data = {
  count: "42",
  price: "19.99",
  active: "true",
  date: "2024-01-15",
  amount: "123.45"
}

puts "\nString data requiring coercion:"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_coerce.safe_parse(coerce_data) }
  x.report("dry-validation") { dry_coerce.call(coerce_data) }

  x.compare!
end

# ==============================================================================
# Complex Validation Rules Benchmark
# ==============================================================================

puts "\n" + "-" * 70
puts "6. Complex Validation (custom rules)"
puts "-" * 70

# Validrb with custom validation
validrb_complex = Validrb.schema do
  field :password, :string, refine: [
    { check: ->(v) { v.length >= 8 }, message: "min 8 chars" },
    { check: ->(v) { v.match?(/[A-Z]/) }, message: "need uppercase" },
    { check: ->(v) { v.match?(/[0-9]/) }, message: "need number" }
  ]
  field :password_confirmation, :string

  validate do |data|
    if data[:password] != data[:password_confirmation]
      error(:password_confirmation, "must match")
    end
  end
end

# dry-validation with rules
class DryComplexContract < Dry::Validation::Contract
  params do
    required(:password).filled(:string)
    required(:password_confirmation).filled(:string)
  end

  rule(:password) do
    key.failure("min 8 chars") if value.length < 8
    key.failure("need uppercase") unless value.match?(/[A-Z]/)
    key.failure("need number") unless value.match?(/[0-9]/)
  end

  rule(:password_confirmation) do
    key.failure("must match") if values[:password] != values[:password_confirmation]
  end
end
dry_complex = DryComplexContract.new

valid_complex_data = { password: "SecurePass1", password_confirmation: "SecurePass1" }
invalid_complex_data = { password: "weak", password_confirmation: "different" }

puts "\nValid data:"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_complex.safe_parse(valid_complex_data) }
  x.report("dry-validation") { dry_complex.call(valid_complex_data) }

  x.compare!
end

puts "\nInvalid data (multiple errors):"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") { validrb_complex.safe_parse(invalid_complex_data) }
  x.report("dry-validation") { dry_complex.call(invalid_complex_data) }

  x.compare!
end

# ==============================================================================
# Schema Creation Benchmark
# ==============================================================================

puts "\n" + "-" * 70
puts "7. Schema Creation (one-time cost)"
puts "-" * 70

puts "\nCreating simple schema:"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Validrb") do
    Validrb.schema do
      field :name, :string, min: 2
      field :email, :string, format: :email
    end
  end

  x.report("dry-validation") do
    Class.new(Dry::Validation::Contract) do
      params do
        required(:name).filled(:string, min_size?: 2)
        required(:email).filled(:string, format?: /@/)
      end
    end.new
  end

  x.compare!
end

puts "\n" + "=" * 70
puts "Benchmark Complete"
puts "=" * 70
