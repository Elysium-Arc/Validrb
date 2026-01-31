# Validrb - Development Context

## Project Overview

Validrb is a Ruby schema validation library with type coercion, inspired by Pydantic (Python) and Zod (TypeScript). It provides a clean DSL for defining data schemas with automatic type coercion, constraint validation, and detailed error reporting.

## Current Status: Phase 5 Complete

All core functionality implemented and tested (719 tests passing).

## Architecture

```
Validrb.schema { ... }
       │
       ▼
    Schema (DSL, parse/safe_parse, composition, introspection)
       │
       ├── Validators (custom cross-field validation + context)
       ├── Serialization (dump/to_json)
       │
       ▼
    Field (preprocess → type → constraints → refinements → transform)
       │
       ├── Conditional (when:/unless: with context)
       ├── Coercion modes (coerce: true/false)
       ├── Literal types (exact value matching)
       ├── Refinements (custom predicates)
       │
       ├──────────────┬──────────────┐
       ▼              ▼              ▼
    Types          Constraints    Context
    (coerce→validate) (min/max/enum/format)  (request context)
       │
       ├── Union types
       ├── Discriminated unions
       ├── Custom types
       │
       ▼
    Result (Success/Failure + serialization)
    Errors (path-tracked, I18n)
```

## File Structure

```
lib/
├── validrb.rb                    # Main entry point
└── validrb/
    ├── version.rb                # VERSION = "0.5.0"
    ├── i18n.rb                   # I18n support for error messages
    ├── errors.rb                 # Error, ErrorCollection, ValidationError
    ├── result.rb                 # Success, Failure result types
    ├── context.rb                # Validation context
    ├── field.rb                  # Field definition with all options
    ├── schema.rb                 # Schema class with DSL Builder + composition
    ├── custom_type.rb            # Custom type DSL
    ├── introspection.rb          # Schema/field introspection
    ├── serializer.rb             # Serialization to primitives/JSON
    ├── openapi.rb                # OpenAPI 3.0 generation and import
    ├── types/
    │   ├── base.rb               # Base type class + registry
    │   ├── string.rb             # String type
    │   ├── integer.rb            # Integer type
    │   ├── float.rb              # Float type
    │   ├── boolean.rb            # Boolean type
    │   ├── array.rb              # Array type with item validation
    │   ├── object.rb             # Object type for nested schemas
    │   ├── date.rb               # Date type
    │   ├── datetime.rb           # DateTime type
    │   ├── time.rb               # Time type
    │   ├── decimal.rb            # Decimal type (BigDecimal)
    │   ├── union.rb              # Union type (multiple types)
    │   ├── literal.rb            # Literal type (exact values)
    │   └── discriminated_union.rb # Discriminated union type
    └── constraints/
        ├── base.rb               # Base constraint class + registry
        ├── min.rb                # Minimum value/length
        ├── max.rb                # Maximum value/length
        ├── length.rb             # Exact/range/min/max length
        ├── format.rb             # Regex or named formats
        └── enum.rb               # Value in allowed list

spec/
├── spec_helper.rb
├── validrb_spec.rb
├── validrb/
│   ├── errors_spec.rb
│   ├── result_spec.rb
│   ├── field_spec.rb
│   ├── schema_spec.rb
│   ├── i18n_spec.rb
│   ├── context_spec.rb
│   ├── custom_type_spec.rb
│   ├── serializer_spec.rb
│   ├── introspection_spec.rb
│   ├── openapi_spec.rb
│   ├── types/*.rb
│   └── constraints/*.rb
└── integration/
    ├── basic_schema_spec.rb
    ├── nested_schema_spec.rb
    ├── phase2_features_spec.rb
    ├── phase3_features_spec.rb
    ├── phase4_features_spec.rb
    └── phase4_edge_cases_spec.rb
```

## API Reference

### Schema Definition

```ruby
schema = Validrb.schema do
  # Basic fields
  field :name, :string
  field :age, :integer, optional: true
  field :role, :string, default: "user"

  # Constraints
  field :email, :string, format: :email
  field :bio, :string, min: 10, max: 500
  field :status, :string, enum: %w[active inactive]

  # Preprocessing (runs BEFORE validation)
  field :username, :string, preprocess: ->(v) { v.strip.downcase }

  # Transform (runs AFTER validation)
  field :tags, :string, transform: ->(v) { v.split(",") }

  # Nullable (accepts nil)
  field :deleted_at, :datetime, nullable: true

  # Union types (accepts multiple types)
  field :id, :string, union: [:integer, :string]

  # Literal types (exact values only)
  field :priority, :integer, literal: [1, 2, 3]

  # Refinements (custom predicates)
  field :password, :string,
        refine: [
          { check: ->(v) { v.length >= 8 }, message: "must be 8+ chars" },
          { check: ->(v) { v.match?(/\d/) }, message: "must contain digit" }
        ]

  # Context-aware refinement
  field :amount, :decimal,
        refine: ->(v, ctx) { ctx.nil? || v <= ctx[:max_amount] }

  # Disable coercion
  field :count, :integer, coerce: false

  # Conditional validation (supports context)
  field :company, :string, when: ->(d, ctx) { d[:account_type] == "business" }
  field :personal_id, :string, unless: :is_company

  # Custom error message
  field :note, :string, min: 8, message: "must be at least 8 characters"

  # Nested schema
  field :address, :object, schema: AddressSchema

  # Typed arrays
  field :scores, :array, of: :integer

  # Discriminated union
  field :payment, :discriminated_union,
        discriminator: :method,
        mapping: { "card" => CardSchema, "paypal" => PaypalSchema }

  # Custom validators (support context)
  validate do |data, ctx|
    if ctx && ctx[:restricted] && data[:amount] > 100
      error(:amount, "exceeds limit in restricted mode")
    end
  end
end
```

### Schema Options

```ruby
# Strict mode - reject unknown keys
Validrb.schema(strict: true) { ... }

# Passthrough mode - keep unknown keys
Validrb.schema(passthrough: true) { ... }
```

### Field Options Reference

| Option | Type | Description |
|--------|------|-------------|
| `optional` | Boolean | Field can be missing (default: false) |
| `nullable` | Boolean | Field accepts nil value (default: false) |
| `default` | Any/Proc | Default value when missing |
| `message` | String | Custom error message |
| `preprocess` | Proc | Transform input BEFORE validation |
| `transform` | Proc | Transform value AFTER validation |
| `coerce` | Boolean | Enable type coercion (default: true) |
| `when` | Proc/Symbol | Only validate if condition is true |
| `unless` | Proc/Symbol | Only validate if condition is false |
| `union` | Array | Accept any of these types |
| `literal` | Array | Accept only these exact values |
| `refine` | Proc/Array | Custom validation predicates |
| `min` | Numeric | Minimum value/length |
| `max` | Numeric | Maximum value/length |
| `length` | Int/Range/Hash | Length constraint |
| `format` | Symbol/Regexp | Format validation |
| `enum` | Array | Allowed values |
| `of` | Symbol | Item type for arrays |
| `schema` | Schema | Nested schema for objects |
| `discriminator` | Symbol | Field for discriminated union |
| `mapping` | Hash | Schemas for discriminated union |

### Type Coercion Rules

| Type | Accepts | Coerces From |
|------|---------|--------------|
| `:string` | String | Symbol, Numeric |
| `:integer` | Integer | String, Float (whole) |
| `:float` | Float | String, Integer |
| `:boolean` | true/false | "true"/"false", "yes"/"no", 1/0, etc. |
| `:array` | Array | (validates items with `of:`) |
| `:object` | Hash | (validates with `schema:`) |
| `:date` | Date | ISO8601 String, Time, DateTime, timestamp |
| `:datetime` | DateTime | ISO8601 String, Time, Date, timestamp |
| `:time` | Time | ISO8601 String, DateTime, Date, timestamp |
| `:decimal` | BigDecimal | String, Integer, Float, Rational |
| `:union` | Any matching | Tries each type in order |
| `:literal` | Exact value | No coercion, exact match only |
| `:discriminated_union` | Object | Selects schema by discriminator field |

### Named Formats

`:email`, `:url`, `:uuid`, `:phone`, `:alphanumeric`, `:alpha`, `:numeric`, `:hex`, `:slug`

### Schema Composition

```ruby
# Extend with additional fields
UserSchema = BaseSchema.extend { field :name, :string }

# Pick specific fields
PublicSchema = FullSchema.pick(:id, :name)

# Omit fields
SafeSchema = FullSchema.omit(:password)

# Merge schemas
MergedSchema = Schema1.merge(Schema2)

# Make all fields optional
UpdateSchema = CreateSchema.partial
```

### I18n Configuration

```ruby
# Add custom translations
Validrb::I18n.add_translations(:en, required: "cannot be blank")

# Change locale
Validrb::I18n.locale = :es

# Add translations for other locales
Validrb::I18n.add_translations(:es, required: "es requerido")

# Use Rails I18n backend
Validrb::I18n.backend = :rails
```

### Validation Context

```ruby
# Create a context
ctx = Validrb.context(user_id: 123, is_admin: true, max_amount: 1000)

# Pass context to parse
result = schema.safe_parse(data, context: ctx)

# Context is available in refinements, conditions, transforms, and validators
field :amount, :decimal, refine: ->(v, ctx) { v <= ctx[:max_amount] }
field :admin_only, :string, when: ->(data, ctx) { ctx[:is_admin] }
```

### Custom Types

```ruby
# Define a custom type
Validrb.define_type(:money) do
  coerce { |v| BigDecimal(v.to_s.gsub(/[$,]/, "")) }
  validate { |v| v >= 0 }
  error_message { "must be a valid money amount" }
end

# Use in schemas
field :price, :money
```

### Schema Introspection

```ruby
# Field inspection
schema.field_names          # => [:id, :name, :email]
schema.required_fields      # => [:id, :name]
schema.optional_fields      # => [:age]
schema.fields_with_defaults # => [:role]
schema.conditional_fields   # => [:company]

# Field details
field = schema.field(:name)
field.constraint_values     # => { min: 1, max: 100 }
field.has_constraint?(Validrb::Constraints::Min) # => true

# Generate JSON Schema
schema.to_json_schema       # => { "$schema": "...", "type": "object", ... }
```

### Serialization

```ruby
# Parse and serialize to hash with primitives
result = schema.safe_parse(data)
result.dump                  # => { "name" => "John", "date" => "2024-01-15" }
result.dump(format: :json)   # => '{"name":"John","date":"2024-01-15"}'
result.to_json               # Same as dump(format: :json)

# Schema-level serialization
schema.dump(data)            # Parse + serialize (raises on error)
schema.safe_dump(data)       # Parse + serialize (returns Result)
```

### Validation Flow

```
Input Value
    │
    ▼
┌─────────────────┐
│ Conditional?    │──No──┐
│ (when:/unless:) │      │
└────────┬────────┘      │
         │Yes            │
         ▼               │
┌─────────────────┐      │
│ Should validate?│──No──┼──► Skip (return nil)
└────────┬────────┘      │
         │Yes            │
         ▼               │
┌─────────────────┐      │
│ Preprocess      │◄─────┘
│ (before coerce) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Type Coercion   │──► coerce: false? → Type Check Only
│ (if enabled)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Constraints     │
│ (min/max/etc)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Transform       │
│ (after valid)   │
└────────┬────────┘
         │
         ▼
    Output Value
```

## Running Tests

```bash
bundle install
bundle exec rspec              # Run all tests
bundle exec rspec --format doc # Verbose output
```

## Version History

### Phase 1 (v0.1.0)
- Basic types (string, integer, float, boolean, array, object)
- Constraints (min, max, length, format, enum)
- Schema DSL, type coercion, nested validation
- Error path tracking, parse/safe_parse

### Phase 2 (v0.2.0)
- Custom validators (cross-field validation)
- Custom error messages
- Date/DateTime/Time types
- Decimal type (BigDecimal)
- Schema composition (extend, merge, pick, omit, partial)
- Unknown keys handling (strict/passthrough)
- Transforms (post-validation)
- Nullable fields

### Phase 3 (v0.3.0)
- Preprocessing (pre-validation transformation)
- Conditional validation (when:/unless:)
- Union types (multiple type acceptance)
- Coercion modes (disable per-field)
- I18n support (internationalized errors)

### Phase 4 (v0.4.0)
- Literal types (exact value matching)
- Refinements (custom validation predicates)
- Validation context (request-level data)
- Schema introspection (field inspection, JSON Schema generation)
- Custom type API (define_type DSL)
- Discriminated unions (type selection by discriminator)
- Serialization (dump to primitives/JSON)

## Future Enhancements

- [ ] Async validators (database checks)
- [ ] Rails integration (ActiveModel compatibility)
- [ ] OpenAPI schema generation
- [ ] Dependent field validation DSL

## Code Conventions

- All files use `# frozen_string_literal: true`
- Zero runtime dependencies (bigdecimal is stdlib)
- Ruby >= 3.0 required
- RSpec for testing
- Objects are frozen/immutable after creation
