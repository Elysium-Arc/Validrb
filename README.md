# Validrb

A modern Ruby library for schema validation, type coercion, and configuration management. Define schemas once, get validation, transformation, JSON Schema generation, and environment variable loading — all in one elegant package.

## The Problem

Every Ruby application that handles external data faces the same challenges:

- Scattered validation logic across controllers, models, and services
- Environment variables loaded as strings without type coercion or validation
- No automatic JSON Schema generation for API documentation
- dry-validation is powerful but verbose and has a steep learning curve
- Dotenv/Figaro load config but don't validate or coerce types
- Serialization, validation, and type definitions are separate concerns
- Each team rebuilds the same data handling infrastructure

## The Solution

Validrb provides unified data validation, transformation, and configuration management as a single Ruby gem. Define your schemas once, and get type-safe parsing, automatic coercion, JSON Schema output, and environment variable loading — with a clean, intuitive API inspired by Pydantic and Zod.

## What You Get

### Validation Features
- Type-safe schema definitions
- Automatic type coercion (strings to integers, dates, booleans)
- Nested object and array validation
- Custom validation rules and constraints
- Discriminated unions for polymorphic data
- Transform pipelines (input type → output type)

### Configuration Features
- Load settings from ENV, .env files, YAML, JSON
- Nested configuration with prefixes (APP_DATABASE_HOST)
- Required vs optional settings with defaults
- Type coercion for environment variables
- Sensitive value masking in logs
- Multiple source priority (ENV > .env > defaults)

### Developer Features
- Simple, intuitive DSL
- Safe parse (returns Result) or strict parse (raises)
- Automatic JSON Schema generation
- Clear, actionable error messages
- Zero runtime dependencies (pure Ruby)
- Full test helpers and matchers

## Use Cases

### API Parameter Validation
Validate incoming API parameters with automatic coercion and clear error messages. Generate OpenAPI schemas directly from your validation definitions.

### Application Configuration
Load and validate configuration from environment variables, .env files, and YAML. Get type-safe config objects instead of stringly-typed ENV access.

### Form Object Validation
Build form objects with complex validation rules, nested attributes, and transformations. Replace scattered ActiveModel validations with centralized schemas.

### Service Object Inputs
Validate inputs to service objects and interactors. Ensure data integrity at service boundaries with explicit contracts.

### Data Import/ETL
Parse and validate external data from CSVs, APIs, and webhooks. Transform data during validation with type-safe pipelines.

## How It Works

### Basic Schema
```ruby
require 'validrb'

UserSchema = Validrb.schema do
  field :name, :string, min: 1, max: 100
  field :email, :string, format: :email
  field :age, :integer, min: 0, max: 150, optional: true
end

# Parse with exceptions on failure
user = UserSchema.parse(params)

# Safe parse returns a Result object
result = UserSchema.safe_parse(params)
if result.success?
  create_user(result.data)
else
  render_errors(result.errors)
end
```

### Type Coercion
Validrb automatically coerces compatible types:
```ruby
schema = Validrb.schema do
  field :count, :integer
  field :active, :boolean
  field :created_at, :datetime
end

# Strings are coerced automatically
schema.parse({
  count: "42",           # => 42
  active: "true",        # => true
  created_at: "2024-01-15T10:30:00Z"  # => DateTime object
})
```

### Transforms
Transform data during validation — input and output types can differ:
```ruby
DateSchema = Validrb.schema do
  field :date, :string, transform: ->(s) { Date.parse(s) }
end

result = DateSchema.parse({ date: "2024-01-15" })
result[:date]  # => #<Date: 2024-01-15>
```

### Settings from Environment
```ruby
class AppConfig < Validrb::Settings
  env_prefix "MYAPP"
  
  setting :port, :integer, default: 3000
  setting :database_url, :string, required: true
  setting :debug, :boolean, default: false
  setting :redis, RedisConfig  # Nested config objects
end

# Reads MYAPP_PORT, MYAPP_DATABASE_URL, MYAPP_DEBUG
config = AppConfig.load
config.port        # => 3000 (coerced from "3000")
config.debug       # => false (coerced from "false")
```

### Discriminated Unions
Handle polymorphic data elegantly:
```ruby
PaymentSchema = Validrb.union(:type,
  card: Validrb.schema {
    field :card_number, :string
    field :cvv, :string, length: 3..4
  },
  bank: Validrb.schema {
    field :account_number, :string
    field :routing_number, :string
  }
)

# Validates only the fields for the matching type
PaymentSchema.parse({ type: "card", card_number: "4111...", cvv: "123" })
```

### JSON Schema Generation
```ruby
UserSchema.to_json_schema
# => {
#   "type": "object",
#   "required": ["name", "email"],
#   "properties": {
#     "name": { "type": "string", "minLength": 1, "maxLength": 100 },
#     "email": { "type": "string", "format": "email" },
#     "age": { "type": "integer", "minimum": 0, "maximum": 150 }
#   }
# }
```

## Architecture Overview

### Core Components
- **Schema**: Definition DSL and validation engine
- **Types**: Built-in types with coercion logic
- **Result**: Success/Failure wrapper for safe parsing
- **Settings**: Environment and config file loading
- **JsonSchema**: JSON Schema generator

### Type System
- Primitives: `string`, `integer`, `float`, `boolean`, `symbol`
- Temporal: `date`, `datetime`, `time`
- Complex: `array`, `hash`, `object`
- Special: `any`, `nil`, `literal`, `enum`, `union`

### Validation Pipeline
1. Type checking and coercion
2. Constraint validation (min, max, format, etc.)
3. Custom rule evaluation
4. Transform application
5. Result assembly

## Project Status

**Current Phase**: Phase 1 - Foundation  
**Status**: Planning  
**Target Release**: v0.1.0

This gem is in active development. APIs and features may change before the 1.0 release.

### What's Working
- Project structure and planning
- Documentation framework
- API design

### In Progress
- Core type system
- Basic schema DSL
- Parse and safe_parse methods

### Next Up
- Constraint validators
- Error message formatting
- Test framework setup

## Roadmap

### Version Timeline

#### v0.1.0 - Foundation (Weeks 1-2) - IN PROGRESS
**Goal**: Basic schema validation with type coercion

**Week 1**
- Gem skeleton and gemspec configuration
- Core type definitions (string, integer, boolean, etc.)
- Schema DSL implementation
- Field definition and registration
- Basic type coercion logic

**Week 2**
- Parse and safe_parse methods
- Result object (Success/Failure)
- Error collection and formatting
- Basic constraint validators (min, max, length)
- RSpec setup with comprehensive tests

**Deliverable**: Working schema validation with coercion

---

#### v0.2.0 - Constraints & Rules (Weeks 3-4) - PLANNED
**Goal**: Rich validation constraints and custom rules

**Week 3**
- Format validators (email, url, uuid, etc.)
- Pattern matching (regex)
- Enum and literal types
- Inclusion/exclusion validators
- Nested object validation

**Week 4**
- Array validation with item schemas
- Custom rule blocks
- Cross-field validation
- Conditional validation (when/then)
- Error message customization

**Deliverable**: Full constraint system with custom rules

---

#### v0.3.0 - Transforms & Unions (Weeks 5-6) - PLANNED
**Goal**: Data transformation and polymorphic types

**Week 5**
- Transform pipeline implementation
- Input/output type tracking
- Chained transforms
- Built-in transforms (strip, downcase, etc.)
- Default value handling

**Week 6**
- Union type implementation
- Discriminated union support
- Efficient discriminator matching
- Union error aggregation
- Optional and nullable fields

**Deliverable**: Transform pipelines and union types

---

#### v0.4.0 - Settings & Config (Weeks 7-8) - PLANNED
**Goal**: Environment and configuration management

**Week 7**
- Settings base class
- ENV variable loading
- Dotenv file parsing
- Type coercion for env strings
- Prefix and naming conventions

**Week 8**
- Nested settings support
- YAML/JSON config sources
- Source priority system
- Required setting validation
- Sensitive value masking

**Deliverable**: Complete configuration management system

---

#### v0.5.0 - JSON Schema (Weeks 9-10) - PLANNED
**Goal**: JSON Schema generation and OpenAPI support

**Week 9**
- JSON Schema generator core
- Type mapping to JSON Schema types
- Constraint mapping (min → minimum, etc.)
- Nested object schema generation
- Array schema generation

**Week 10**
- Union/anyOf schema generation
- Discriminated union schema support
- Ref and definitions for reuse
- OpenAPI 3.0 compatibility
- Schema export utilities

**Deliverable**: Automatic JSON Schema generation

---

#### v1.0.0 - Production Release (Weeks 11-12) - PLANNED
**Goal**: Public gem release with stable API

**Week 11**
- Complete README documentation
- API reference documentation
- Configuration guide
- Migration guide from dry-validation
- Example applications
- Troubleshooting guide

**Week 12**
- Performance optimization
- Memory usage audit
- CI/CD pipeline setup
- Security review
- RubyGems.org release
- Public announcement

**Deliverable**: Production-ready 1.0.0 release

---

### Future Versions (Post 1.0)

#### v1.1.0 - Rails Integration
- ActiveModel compatibility layer
- Form builder helpers
- Controller parameter integration
- I18n for error messages

#### v1.2.0 - Advanced Types
- Recursive schema support
- Lazy schema evaluation
- Branded/nominal types
- Refinement types

#### v1.3.0 - Performance
- Schema compilation/caching
- JIT-friendly hot paths
- Benchmark suite
- Memory optimization

#### v2.0.0 - Extended Ecosystem
- Sorbet/RBS type generation
- GraphQL type generation
- Protocol Buffers support
- MessagePack serialization

## Planned Features

### Phase 1: Foundation
- Core type system (string, integer, boolean, float, symbol)
- Schema DSL with field definitions
- Basic type coercion
- Parse and safe_parse methods
- Result object (Success/Failure)
- Error collection and formatting
- Basic constraints (min, max, length)
- RSpec test setup

### Phase 2: Constraints & Rules
- Format validators (email, url, uuid, regex)
- Enum and literal types
- Inclusion/exclusion validators
- Nested object validation
- Array validation with item schemas
- Custom rule blocks
- Cross-field validation
- Conditional validation (when/then)
- Error message customization

### Phase 3: Transforms & Unions
- Transform pipeline implementation
- Input/output type tracking
- Chained transforms
- Built-in transforms (strip, downcase, etc.)
- Default value handling
- Union type implementation
- Discriminated union support
- Optional and nullable fields

### Phase 4: Settings & Config
- Settings base class
- ENV variable loading
- Dotenv file parsing
- Type coercion for env strings
- Prefix and naming conventions
- Nested settings support
- YAML/JSON config sources
- Source priority system
- Sensitive value masking

### Phase 5: JSON Schema
- JSON Schema generator core
- Type mapping to JSON Schema types
- Constraint mapping
- Nested object schema generation
- Array schema generation
- Union/anyOf schema generation
- Discriminated union schema support
- OpenAPI 3.0 compatibility

### Phase 6: Production Ready
- Complete documentation
- API reference
- Migration guide from dry-validation
- Example applications
- Performance optimization
- CI/CD pipeline
- Security review
- Initial gem release

### Future Enhancements
- Rails/ActiveModel integration
- I18n for error messages
- Recursive schema support
- Branded/nominal types
- Schema compilation/caching
- Sorbet/RBS type generation
- GraphQL type generation
- Protocol Buffers support

## Requirements

- Ruby 3.0 or higher
- No runtime dependencies (pure Ruby)

### Optional Dependencies
- `dotenv` - For .env file loading in Settings
- `oj` - For faster JSON Schema serialization

## Comparison with Alternatives

| Feature | Validrb | dry-validation | ActiveModel | Pydantic |
|---------|---------|----------------|-------------|----------|
| Type coercion | ✅ | ✅ | ❌ | ✅ |
| Settings/ENV loading | ✅ | ❌ | ❌ | ✅ |
| JSON Schema generation | ✅ | ❌ | ❌ | ✅ |
| Transforms | ✅ | ❌ | ❌ | ✅ |
| Discriminated unions | ✅ | ❌ | ❌ | ❌ |
| Safe parse (Result) | ✅ | ✅ | ❌ | ❌ |
| Learning curve | Low | High | Low | Low |
| Dependencies | 0 | Many | Rails | Many |

## Documentation

Documentation is organized into several resources:

### Repository Documentation
- README: Project overview and getting started
- ARCHITECTURE.md: Technical design decisions
- CONTRIBUTING.md: Development guidelines
- CHANGELOG.md: Version history

### Guides (Planned)
- Getting Started Guide
- Schema Definition Reference
- Settings & Configuration Guide
- JSON Schema Generation Guide
- Migration from dry-validation
- Best Practices

### API Reference (Planned)
- Schema DSL
- Built-in Types
- Constraints
- Settings Class
- Result Object

## Development Approach

Development follows a structured approach with clear phases. Each phase delivers a working, tested increment.

### Development Workflow
1. Phase planning and issue creation
2. Feature breakdown into small PRs
3. Test-driven development
4. Pull request with review
5. Documentation updates
6. Release and changelog

### Testing Strategy
- Unit tests for all types and validators
- Integration tests for schema parsing
- Property-based testing for coercion
- Benchmark tests for performance
- Comparison tests against dry-validation

### Design Principles
- **Simplicity over features**: Easy API for common cases
- **Explicit over implicit**: No magic, clear behavior
- **Performance matters**: Hot paths are optimized
- **Zero dependencies**: Pure Ruby, no bloat
- **Inspired by the best**: Learn from Pydantic and Zod

## Contributing

Contributions are welcome once the initial foundation is established. Guidelines will be provided in CONTRIBUTING.md.

### Areas for Contribution
- Additional built-in types
- Format validators
- Documentation improvements
- Performance optimizations
- Bug fixes and test coverage

## License

MIT License. See LICENSE file for details.

## Author

[Your Name]

## Links

- Repository: https://github.com/[username]/validrb
- Documentation: https://github.com/[username]/validrb/wiki
- Issues: https://github.com/[username]/validrb/issues
- RubyGems: https://rubygems.org/gems/validrb (after release)

---

**Note**: This is a greenfield project in initial development. Watch the repository for updates as features are implemented.
