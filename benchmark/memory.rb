#!/usr/bin/env ruby
# frozen_string_literal: true

# Memory usage comparison between Validrb and dry-validation
#
# Run with: bundle exec ruby benchmark/memory.rb

require "bundler/setup"
require "memory_profiler"
require "validrb"
require "dry-validation"

puts "=" * 70
puts "Memory Usage Comparison: Validrb vs dry-validation"
puts "=" * 70
puts

# ==============================================================================
# Helper method
# ==============================================================================

def profile_memory(name, iterations: 1000, &block)
  # Warm up
  10.times { block.call }

  # Force GC before profiling
  GC.start

  report = MemoryProfiler.report do
    iterations.times { block.call }
  end

  puts "#{name} (#{iterations} iterations):"
  puts "  Total allocated: #{(report.total_allocated_memsize / 1024.0).round(2)} KB"
  puts "  Total retained:  #{(report.total_retained_memsize / 1024.0).round(2)} KB"
  puts "  Objects allocated: #{report.total_allocated}"
  puts "  Objects retained:  #{report.total_retained}"
  puts

  report
end

# ==============================================================================
# Simple Schema Memory Usage
# ==============================================================================

puts "-" * 70
puts "1. Simple Schema Validation"
puts "-" * 70
puts

# Validrb schema
validrb_simple = Validrb.schema do
  field :name, :string, min: 2, max: 100
  field :email, :string, format: :email
  field :age, :integer, min: 0
end

# dry-validation contract
class DrySimple < Dry::Validation::Contract
  params do
    required(:name).filled(:string, min_size?: 2, max_size?: 100)
    required(:email).filled(:string, format?: /@/)
    required(:age).filled(:integer, gteq?: 0)
  end
end
dry_simple = DrySimple.new

data = { name: "John Doe", email: "john@example.com", age: 30 }

validrb_report = profile_memory("Validrb") { validrb_simple.safe_parse(data) }
dry_report = profile_memory("dry-validation") { dry_simple.call(data) }

# ==============================================================================
# Nested Schema Memory Usage
# ==============================================================================

puts "-" * 70
puts "2. Nested Schema Validation"
puts "-" * 70
puts

validrb_nested = Validrb.schema do
  field :user, :object do
    field :name, :string
    field :email, :string, format: :email
    field :profile, :object do
      field :bio, :string, max: 500
      field :age, :integer
    end
  end
end

class DryNested < Dry::Validation::Contract
  params do
    required(:user).hash do
      required(:name).filled(:string)
      required(:email).filled(:string, format?: /@/)
      required(:profile).hash do
        required(:bio).filled(:string, max_size?: 500)
        required(:age).filled(:integer)
      end
    end
  end
end
dry_nested = DryNested.new

nested_data = {
  user: {
    name: "John",
    email: "john@example.com",
    profile: { bio: "Developer", age: 30 }
  }
}

profile_memory("Validrb") { validrb_nested.safe_parse(nested_data) }
profile_memory("dry-validation") { dry_nested.call(nested_data) }

# ==============================================================================
# Array Validation Memory Usage
# ==============================================================================

puts "-" * 70
puts "3. Array Validation (50 items)"
puts "-" * 70
puts

validrb_array = Validrb.schema do
  field :items, :array do
    field :id, :integer
    field :name, :string
    field :price, :decimal
  end
end

class DryArray < Dry::Validation::Contract
  params do
    required(:items).array(:hash) do
      required(:id).filled(:integer)
      required(:name).filled(:string)
      required(:price).filled(:decimal)
    end
  end
end
dry_array = DryArray.new

array_data = {
  items: 50.times.map { |i| { id: i, name: "Item #{i}", price: "#{i}.99" } }
}

profile_memory("Validrb", iterations: 100) { validrb_array.safe_parse(array_data) }
profile_memory("dry-validation", iterations: 100) { dry_array.call(array_data) }

# ==============================================================================
# Schema Creation Memory Usage
# ==============================================================================

puts "-" * 70
puts "4. Schema Creation Memory"
puts "-" * 70
puts

profile_memory("Validrb schema creation", iterations: 100) do
  Validrb.schema do
    field :name, :string, min: 2
    field :email, :string, format: :email
    field :age, :integer
  end
end

profile_memory("dry-validation contract creation", iterations: 100) do
  Class.new(Dry::Validation::Contract) do
    params do
      required(:name).filled(:string, min_size?: 2)
      required(:email).filled(:string, format?: /@/)
      required(:age).filled(:integer)
    end
  end.new
end

# ==============================================================================
# Type Coercion Memory Usage
# ==============================================================================

puts "-" * 70
puts "5. Type Coercion Memory"
puts "-" * 70
puts

validrb_coerce = Validrb.schema do
  field :int_val, :integer
  field :float_val, :float
  field :bool_val, :boolean
  field :date_val, :date
  field :decimal_val, :decimal
end

class DryCoerce < Dry::Validation::Contract
  params do
    required(:int_val).filled(:integer)
    required(:float_val).filled(:float)
    required(:bool_val).filled(:bool)
    required(:date_val).filled(:date)
    required(:decimal_val).filled(:decimal)
  end
end
dry_coerce = DryCoerce.new

coerce_data = {
  int_val: "42",
  float_val: "3.14",
  bool_val: "true",
  date_val: "2024-01-15",
  decimal_val: "123.456"
}

profile_memory("Validrb") { validrb_coerce.safe_parse(coerce_data) }
profile_memory("dry-validation") { dry_coerce.call(coerce_data) }

# ==============================================================================
# Detailed Memory Report for Validrb
# ==============================================================================

puts "-" * 70
puts "6. Detailed Memory Report (Validrb simple validation)"
puts "-" * 70
puts

GC.start
report = MemoryProfiler.report do
  1000.times { validrb_simple.safe_parse(data) }
end

puts "Top 10 memory allocations by gem:"
report.pretty_print(scale_bytes: true, detailed_report: false)

puts "\n" + "=" * 70
puts "Memory Analysis Complete"
puts "=" * 70
