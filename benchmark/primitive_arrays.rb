#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark for arrays of primitive types (where optimization helps most)
#
# Run with: bundle exec ruby benchmark/primitive_arrays.rb

require "bundler/setup"
require "benchmark/ips"
require "memory_profiler"
require "validrb"
require "dry-validation"

puts "=" * 70
puts "Primitive Array Performance Benchmark"
puts "=" * 70
puts

# ==============================================================================
# Schema Definitions
# ==============================================================================

# Validrb schemas for primitive arrays
validrb_strings = Validrb.schema do
  field :values, :array, of: :string
end

validrb_integers = Validrb.schema do
  field :values, :array, of: :integer
end

validrb_mixed = Validrb.schema do
  field :strings, :array, of: :string
  field :integers, :array, of: :integer
  field :floats, :array, of: :float
  field :booleans, :array, of: :boolean
end

# dry-validation contracts
class DryStrings < Dry::Validation::Contract
  params do
    required(:values).array(:string)
  end
end
dry_strings = DryStrings.new

class DryIntegers < Dry::Validation::Contract
  params do
    required(:values).array(:integer)
  end
end
dry_integers = DryIntegers.new

class DryMixed < Dry::Validation::Contract
  params do
    required(:strings).array(:string)
    required(:integers).array(:integer)
    required(:floats).array(:float)
    required(:booleans).array(:bool)
  end
end
dry_mixed = DryMixed.new

# ==============================================================================
# Speed Benchmarks
# ==============================================================================

puts "-" * 70
puts "1. Array of Strings (50 items)"
puts "-" * 70

string_data = { values: 50.times.map { |i| "value_#{i}" } }

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report("Validrb") { validrb_strings.safe_parse(string_data) }
  x.report("dry-validation") { dry_strings.call(string_data) }

  x.compare!
end

puts "\n" + "-" * 70
puts "2. Array of Integers (50 items with coercion)"
puts "-" * 70

integer_data = { values: 50.times.map { |i| i.to_s } }

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report("Validrb") { validrb_integers.safe_parse(integer_data) }
  x.report("dry-validation") { dry_integers.call(integer_data) }

  x.compare!
end

puts "\n" + "-" * 70
puts "3. Mixed Primitive Arrays (4 arrays x 25 items)"
puts "-" * 70

mixed_data = {
  strings: 25.times.map { |i| "str_#{i}" },
  integers: 25.times.map { |i| i.to_s },
  floats: 25.times.map { |i| "#{i}.5" },
  booleans: 25.times.map { |i| i.even? ? "true" : "false" }
}

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report("Validrb") { validrb_mixed.safe_parse(mixed_data) }
  x.report("dry-validation") { dry_mixed.call(mixed_data) }

  x.compare!
end

# ==============================================================================
# Scaling Test
# ==============================================================================

puts "\n" + "-" * 70
puts "4. Scaling: Array of Integers"
puts "-" * 70

[10, 50, 100, 500, 1000].each do |size|
  data = { values: size.times.map(&:to_s) }

  puts "\n#{size} items:"
  Benchmark.ips do |x|
    x.config(time: 2, warmup: 1)

    x.report("Validrb") { validrb_integers.safe_parse(data) }
    x.report("dry-validation") { dry_integers.call(data) }

    x.compare!
  end
end

# ==============================================================================
# Memory Comparison
# ==============================================================================

puts "\n" + "-" * 70
puts "5. Memory: Array of Integers (100 items)"
puts "-" * 70
puts

data_100 = { values: 100.times.map(&:to_s) }

GC.start
validrb_report = MemoryProfiler.report { 100.times { validrb_integers.safe_parse(data_100) } }
puts "Validrb (100 iterations):"
puts "  Total allocated: #{(validrb_report.total_allocated_memsize / 1024.0).round(2)} KB"
puts "  Objects allocated: #{validrb_report.total_allocated}"
puts

GC.start
dry_report = MemoryProfiler.report { 100.times { dry_integers.call(data_100) } }
puts "dry-validation (100 iterations):"
puts "  Total allocated: #{(dry_report.total_allocated_memsize / 1024.0).round(2)} KB"
puts "  Objects allocated: #{dry_report.total_allocated}"
puts

# ==============================================================================
# Invalid Data Performance
# ==============================================================================

puts "-" * 70
puts "6. Invalid Array Data (type errors)"
puts "-" * 70

invalid_data = { values: 50.times.map { |i| i.even? ? i.to_s : "not_a_number_#{i}" } }

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report("Validrb") { validrb_integers.safe_parse(invalid_data) }
  x.report("dry-validation") { dry_integers.call(invalid_data) }

  x.compare!
end

puts "\n" + "=" * 70
puts "Benchmark Complete"
puts "=" * 70
