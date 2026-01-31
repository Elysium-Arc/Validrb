# Validrb - Development Context

## Project Overview

Validrb is a Ruby schema validation library with type coercion, inspired by Pydantic (Python) and Zod (TypeScript). It provides a clean DSL for defining data schemas with automatic type coercion, constraint validation, and detailed error reporting.

## Current Status: Phase 2 Complete

All core functionality implemented and tested (444 tests passing).

## Architecture

```
Validrb.schema { ... }
       │
       ▼
    Schema (DSL, parse/safe_parse, composition)
       │
       ├── Validators (custom cross-field validation)
       │
       ▼
    Field (type + constraints + transform + nullable)
       │
       ├──────────────┐
       ▼              ▼
    Types          Constraints
    (coerce→validate) (min/max/enum/format)
       │
       ▼
    Result (Success/Failure)
    Errors (path-tracked)
```

## File Structure

```
lib/
├── validrb.rb                    # Main entry point, requires all components
└── validrb/
    ├── version.rb                # VERSION = "0.2.0"
    ├── errors.rb                 # Error, ErrorCollection, ValidationError
    ├── result.rb                 # Success, Failure result types
    ├── field.rb                  # Field definition (type + constraints + options)
    ├── schema.rb                 # Schema class with DSL Builder + composition
    ├── types/
    │   ├── base.rb               # Base type class + registry + COERCION_FAILED sentinel
    │   ├── string.rb             # String type (coerces Symbol, Numeric)
    │   ├── integer.rb            # Integer type (coerces String, whole Floats)
    │   ├── float.rb              # Float type (coerces String, Integer)
    │   ├── boolean.rb            # Boolean type (coerces "true"/"false", 1/0, "yes"/"no")
    │   ├── array.rb              # Array type with optional item type (of: :type)
    │   ├── object.rb             # Object type for nested schemas (schema: NestedSchema)
    │   ├── date.rb               # Date type (coerces ISO8601 strings, timestamps)
    │   ├── datetime.rb           # DateTime type (coerces ISO8601, timestamps)
    │   ├── time.rb               # Time type (coerces ISO8601, timestamps)
    │   └── decimal.rb            # Decimal type using BigDecimal
    └── constraints/
        ├── base.rb               # Base constraint class + registry
        ├── min.rb                # Minimum value/length constraint
        ├── max.rb                # Maximum value/length constraint
        ├── length.rb             # Exact/range/min/max length constraint
        ├── format.rb             # Regex or named format (:email, :url, :uuid, etc.)
        └── enum.rb               # Value in allowed list constraint

spec/
├── spec_helper.rb
├── validrb_spec.rb
├── validrb/
│   ├── errors_spec.rb
│   ├── result_spec.rb
│   ├── field_spec.rb
│   ├── schema_spec.rb
│   ├── types/
│   │   ├── string_spec.rb
│   │   ├── integer_spec.rb
│   │   ├── float_spec.rb
│   │   ├── boolean_spec.rb
│   │   ├── array_spec.rb
│   │   ├── object_spec.rb
│   │   ├── date_spec.rb
│   │   ├── datetime_spec.rb
│   │   ├── time_spec.rb
│   │   └── decimal_spec.rb
│   └── constraints/
│       ├── min_spec.rb
│       ├── max_spec.rb
│       ├── length_spec.rb
│       ├── format_spec.rb
│       └── enum_spec.rb
└── integration/
    ├── basic_schema_spec.rb
    ├── nested_schema_spec.rb
    └── phase2_features_spec.rb
```

## Key Design Decisions

1. **Immutability**: All schemas, fields, types, constraints are frozen after creation
2. **COERCION_FAILED sentinel**: Distinguishes failed coercion from nil values (`lib/validrb/types/base.rb:9`)
3. **MISSING sentinel**: Distinguishes missing keys from nil values (`lib/validrb/field.rb:7`)
4. **Self-registering types/constraints**: Each type/constraint registers itself (e.g., `Types.register(:string, String)`)
5. **Type-aware constraints**: `min:/max:` means length for strings/arrays, value for numbers
6. **Symbol/String key normalization**: Input accepts both, output always uses symbols
7. **Path tracking**: Errors include full path like `[:user, :address, :city]`
8. **Validators run after field validation**: Custom validators only execute if all fields pass

## API Reference

### Schema Definition

```ruby
schema = Validrb.schema do
  field :name, :string                          # Required field
  field :age, :integer, optional: true          # Optional field
  field :role, :string, default: "user"         # Default value
  field :status, :string, enum: %w[a b c]       # Enum constraint
  field :email, :string, format: :email         # Format constraint
  field :bio, :string, min: 10, max: 500        # Min/max constraints
  field :code, :string, length: 6               # Exact length
  field :tags, :array, of: :string              # Typed array
  field :address, :object, schema: AddrSchema   # Nested schema
  field :nickname, :string, nullable: true      # Accepts nil
  field :slug, :string, transform: ->(v) { v.downcase }  # Transform

  optional :nickname, :string                   # Shorthand for optional: true
  required :password, :string                   # Explicit required (default)

  # Custom validators (run after field validation)
  validate do |data|
    if data[:password] != data[:password_confirmation]
      error(:password_confirmation, "doesn't match")
    end
  end
end
```

### Schema Options

```ruby
# Strict mode - reject unknown keys
Validrb.schema(strict: true) do
  field :name, :string
end

# Passthrough mode - keep unknown keys in output
Validrb.schema(passthrough: true) do
  field :name, :string
end
```

### Schema Composition

```ruby
# Extend schema with additional fields
ExtendedSchema = BaseSchema.extend do
  field :extra, :string
end

# Pick specific fields
PublicSchema = FullSchema.pick(:id, :name, :email)

# Omit fields
SafeSchema = FullSchema.omit(:password, :secret)

# Merge two schemas (second takes precedence)
MergedSchema = Schema1.merge(Schema2)

# Make all fields optional (useful for PATCH updates)
UpdateSchema = CreateSchema.partial
```

### Parsing

```ruby
# Returns data or raises Validrb::ValidationError
data = schema.parse(input)

# Returns Validrb::Success or Validrb::Failure
result = schema.safe_parse(input)
result.success?          # true/false
result.failure?          # true/false
result.data              # validated hash (Success) or nil (Failure)
result.errors            # ErrorCollection
result.errors.to_h       # { "field.path" => ["message1", "message2"] }
result.errors.full_messages  # ["field.path: message1", ...]
```

### Type Coercion Rules

| Type | Accepts | Coerces From |
|------|---------|--------------|
| `:string` | String | Symbol, Numeric |
| `:integer` | Integer | String ("42"), Float (42.0 only) |
| `:float` | Float (finite) | String ("3.14"), Integer |
| `:boolean` | true/false | "true"/"false", "yes"/"no", "on"/"off", "t"/"f", "y"/"n", "1"/"0", 1/0 |
| `:array` | Array | - (validates items with `of:`) |
| `:object` | Hash | - (validates with `schema:`) |
| `:date` | Date | String (ISO8601), Time, DateTime, Integer (timestamp) |
| `:datetime` | DateTime | String (ISO8601), Time, Date, Integer/Float (timestamp) |
| `:time` | Time | String (ISO8601), DateTime, Date, Integer/Float (timestamp) |
| `:decimal` | BigDecimal | String, Integer, Float, Rational |

### Named Formats (lib/validrb/constraints/format.rb)

- `:email` - Email addresses
- `:url` - HTTP/HTTPS URLs
- `:uuid` - UUID v4 format
- `:phone` - Phone numbers (lenient)
- `:alphanumeric` - Letters and numbers only
- `:alpha` - Letters only
- `:numeric` - Digits only
- `:hex` - Hexadecimal characters
- `:slug` - URL slugs (lowercase, hyphens)

### Field Options

| Option | Type | Description |
|--------|------|-------------|
| `optional` | Boolean | Field can be missing (default: false) |
| `nullable` | Boolean | Field accepts nil value (default: false) |
| `default` | Any/Proc | Default value when missing |
| `message` | String | Custom error message for all errors |
| `transform` | Proc | Transform value after validation |
| `min` | Numeric | Minimum value/length |
| `max` | Numeric | Maximum value/length |
| `length` | Integer/Range/Hash | Exact or range length |
| `format` | Symbol/Regexp | Format validation |
| `enum` | Array | Allowed values |

### Custom Validators

```ruby
schema = Validrb.schema do
  field :start_date, :date
  field :end_date, :date

  validate do |data|
    # Access fields via data hash or self[]
    if data[:end_date] < data[:start_date]
      error(:end_date, "must be after start date")
    end
  end

  validate do
    # Base-level error (not tied to field)
    base_error("Invalid date range") if self[:start_date] > Date.today
  end
end
```

## Running Tests

```bash
bundle install
bundle exec rspec           # Run all tests
bundle exec rspec --format doc  # Verbose output
```

## Phase 1 Features (v0.1.0) ✓

- [x] Basic types (string, integer, float, boolean, array, object)
- [x] Constraints (min, max, length, format, enum)
- [x] Schema DSL with field definitions
- [x] Type coercion
- [x] Nested schema validation
- [x] Path-tracked errors
- [x] parse() and safe_parse() methods

## Phase 2 Features (v0.2.0) ✓

- [x] Custom validators (cross-field validation)
- [x] Custom error messages per field
- [x] Date/DateTime/Time types
- [x] Decimal type (BigDecimal)
- [x] Schema composition (extend, merge, pick, omit, partial)
- [x] Unknown keys handling (strict/passthrough modes)
- [x] Transforms (post-validation data transformation)
- [x] Nullable type (explicit nil handling)

## Future Enhancements (Phase 3+)

- [ ] Async validators (for database checks)
- [ ] Conditional validation (when: / unless:)
- [ ] Custom type registration API
- [ ] Rails integration (ActiveModel compatibility)
- [ ] Serialization (to_json, to_hash)
- [ ] OpenAPI schema generation
- [ ] I18n support for error messages

## Code Conventions

- All files use `# frozen_string_literal: true`
- Zero runtime dependencies (bigdecimal is stdlib)
- Ruby >= 3.0 required
- RSpec for testing
- Objects are frozen/immutable after creation
