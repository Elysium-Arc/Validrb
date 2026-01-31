# Validrb Performance Benchmarks

Performance comparison between Validrb and dry-validation.

**Test Environment:**
- Ruby 3.3.10
- Linux x86_64
- Benchmark-ips v2.12

## Summary

| Scenario | Validrb | dry-validation | Improvement |
|----------|---------|----------------|-------------|
| Simple schema (valid) | 238k i/s | 70k i/s | **3.4x faster** |
| Simple schema (invalid) | 154k i/s | 7k i/s | **22x faster** |
| Nested schema | 126k i/s | 46k i/s | **2.7x faster** |
| Array (10 items) | 23k i/s | 12k i/s | **1.9x faster** |
| Array (100 items) | 2.5k i/s | 1.4k i/s | **1.75x faster** |
| Type coercion | 141k i/s | 48k i/s | **3x faster** |
| Complex validation (valid) | 369k i/s | 38k i/s | **9.6x faster** |
| Complex validation (invalid) | 247k i/s | 17k i/s | **14.7x faster** |
| Schema creation | 168k i/s | 919 i/s | **183x faster** |

## Key Findings

### Speed

1. **Validrb is 2-3x faster** for typical validation scenarios
2. **Error handling is 13-20x faster** - critical for API validation
3. **Schema creation is 184x faster** - ideal for dynamic schemas
4. **Performance advantage grows with complexity**

### Memory

| Scenario | Validrb | dry-validation | Winner |
|----------|---------|----------------|--------|
| Schema creation | 0.6 MB | 25.3 MB | **Validrb (43x less)** |
| Simple validation | 0.8 MB | 2.2 MB | **Validrb (63% less)** |
| Type coercion | 2.1 MB | 3.0 MB | **Validrb (30% less)** |
| Nested objects | 2.2 MB | 3.1 MB | **Validrb (30% less)** |
| Validation errors | 2.5 MB | 46.3 MB | **Validrb (95% less)** |
| Large arrays | 6.0 MB | 3.1 MB | dry-validation (48% less) |

### When to Use Each

**Choose Validrb when:**
- Building APIs with frequent validation
- Handling invalid input (error paths)
- Creating schemas dynamically
- Memory efficiency for schema storage
- Simple to medium complexity schemas

**Choose dry-validation when:**
- Validating very large arrays (500+ items)
- Memory is critical for data processing

## Detailed Benchmarks

### Simple Schema Validation

```ruby
# Validrb
schema = Validrb.schema do
  field :name, :string, min: 2, max: 100
  field :email, :string, format: :email
  field :age, :integer, min: 0, max: 150
end

# dry-validation
class Contract < Dry::Validation::Contract
  params do
    required(:name).filled(:string, min_size?: 2, max_size?: 100)
    required(:email).filled(:string, format?: /@/)
    required(:age).filled(:integer, gteq?: 0, lteq?: 150)
  end
end
```

Results (valid data):
- Validrb: 205,278 i/s (4.87 μs/call)
- dry-validation: 73,874 i/s (13.54 μs/call)
- **Validrb is 2.78x faster**

Results (invalid data with 3 errors):
- Validrb: 139,651 i/s (7.16 μs/call)
- dry-validation: 6,927 i/s (144.36 μs/call)
- **Validrb is 20x faster**

### Nested Schema Validation

```ruby
# Validrb
schema = Validrb.schema do
  field :name, :string, min: 2
  field :email, :string, format: :email
  field :address, :object do
    field :street, :string, min: 1
    field :city, :string, min: 1
    field :state, :string, length: 2
    field :zip, :string, format: /\A\d{5}\z/
  end
end
```

Results:
- Validrb: 108,337 i/s (9.23 μs/call)
- dry-validation: 45,939 i/s (21.77 μs/call)
- **Validrb is 2.36x faster**

### Array Validation

| Array Size | Validrb | dry-validation | Improvement |
|------------|---------|----------------|-------------|
| 10 items | 20.3k i/s | 12.3k i/s | 1.65x faster |
| 50 items | 3.2k i/s | 2.2k i/s | 1.44x faster |
| 100 items | 2.2k i/s | 1.5k i/s | 1.43x faster |

### Schema Creation

Creating new schemas at runtime:

- Validrb: 181,499 i/s (5.51 μs/call)
- dry-validation: 983 i/s (1.02 ms/call)
- **Validrb is 184x faster**

This makes Validrb ideal for:
- Multi-tenant systems with dynamic schemas
- Schema composition (extend, pick, omit)
- Testing with schema variations

### Schema Composition

Validrb-specific features:

| Operation | Performance |
|-----------|-------------|
| `schema.extend { ... }` | 337k i/s |
| `schema.pick(:a, :b)` | 676k i/s |
| `schema.partial` | 139k i/s |

### Throughput Test

Maximum validations per second (simple 2-field schema):

- Validrb: **415,303 i/s** (2.41 μs/call)
- dry-validation: 83,960 i/s (11.91 μs/call)
- **Validrb is 4.95x faster**

## Running Benchmarks

```bash
# Speed comparison
bundle exec ruby benchmark/comparison.rb

# Comprehensive suite
bundle exec ruby benchmark/comprehensive.rb

# Memory analysis
bundle exec ruby benchmark/memory.rb
bundle exec ruby benchmark/memory_detailed.rb

# Primitive arrays
bundle exec ruby benchmark/primitive_arrays.rb
```

## Memory Analysis

### Zero Memory Leaks

Validrb has **zero retained memory** across all benchmarks, indicating no memory leaks. All objects are properly garbage collected.

### Allocation Breakdown

For simple validation (1000 iterations):

| Class | Memory |
|-------|--------|
| Array | 625 KB |
| Hash | 469 KB |
| ValidatorContext | 78 KB |
| Success | 39 KB |

### Schema Creation Memory

| Library | Memory | Objects | Retained |
|---------|--------|---------|----------|
| Validrb | 609 KB | 5,000 | 0 |
| dry-validation | 26.8 MB | 317,202 | 2.7 MB |

dry-validation retains significant memory per contract class, making it less suitable for dynamic schema creation.

## Optimization Notes

### What Makes Validrb Fast

1. **Frozen immutable objects** - Schemas, fields, types are frozen after creation
2. **Cached type resolution** - Item types resolved once, not per-validation
3. **Lazy error path building** - Paths only built when errors occur
4. **Minimal allocations** - Frozen empty arrays reused
5. **No metaprogramming overhead** - Direct method calls

### Trade-offs

- **Array validation memory**: Validrb allocates more per item due to type-per-item validation. For arrays over 500 items with complex items, dry-validation may use less memory.
- **Feature parity**: dry-validation has more advanced features (macros, external validations). Validrb focuses on core validation with maximum performance.
