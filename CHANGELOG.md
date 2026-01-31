# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2024-01-31

### Added
- **Rails Integration** - Full Rails support with form objects, controller helpers, and ActiveRecord validation
  - `Validrb::Rails::FormObject` - ActiveModel-compatible form objects for Rails forms
  - `Validrb::Rails::Controller` - Controller helpers (`validate_params`, `validate_params!`, `build_form`)
  - `Validrb::Rails::Model` - ActiveRecord integration with `validates_with_schema`
  - `Validrb::Rails::ErrorConverter` - Convert Validrb errors to ActiveModel::Errors
  - Auto-configuration via Rails Railtie
- **Inline nested schemas** - Define nested schemas directly in field blocks
  ```ruby
  field :address, :object do
    field :street, :string
    field :city, :string
  end
  ```
- **Array of schemas shorthand** - Pass Schema instances directly to `of:` option
  ```ruby
  field :items, :array, of: ItemSchema  # No wrapper needed
  ```
- **OpenAPI convenience methods** on Generator:
  - `request_body(schema)` - Generate request body structure
  - `query_params(schema)` - Convert schema to query parameters
  - `path_params(*names)` - Generate path parameters
  - `response_schema(schema)` - Generate response with schema
  - `response(description)` - Generate simple response
  - `error_response` - Generate standard error response structure

### Changed
- `parse` and `safe_parse` now accept both hash and kwargs syntax:
  ```ruby
  schema.safe_parse({ name: "John" })  # Hash syntax
  schema.safe_parse(name: "John")      # Kwargs syntax (new)
  ```
- Added `bigdecimal` as explicit dependency (required for Ruby 3.4+)

## [0.5.0] - 2024-01-15

### Added
- **OpenAPI 3.0 Generation** - Generate complete OpenAPI specs from schemas
- **OpenAPI Import** - Create Validrb schemas from OpenAPI/JSON Schema definitions
- `Validrb::OpenAPI::Generator` for building OpenAPI documents
- `Validrb::OpenAPI::PathBuilder` for defining API endpoints
- `Validrb::OpenAPI::Importer` for importing external schemas
- `Schema#to_openapi` method for single schema export
- Support for servers, paths, and component schemas in OpenAPI output
- JSON and YAML export formats

### Production Readiness
- Comprehensive README documentation
- CHANGELOG following Keep a Changelog format
- GitHub Actions CI workflow for Ruby 3.0-3.3
- Updated gemspec with full metadata

## [0.4.0] - 2024-01-15

### Added
- **Literal types** - Exact value matching with `literal:` option
- **Refinements** - Custom validation predicates with `refine:` option
- **Validation context** - Pass request-level data through validation pipeline
- **Schema introspection** - `field_names`, `required_fields`, `optional_fields`, `to_schema_hash`
- **JSON Schema generation** - `to_json_schema` method for JSON Schema Draft-07 output
- **Custom type API** - `Validrb.define_type` DSL for creating custom types
- **Discriminated unions** - Schema selection based on discriminator field
- **Serialization** - `dump` and `to_json` methods for converting data to primitives
- Context support in transforms, preprocessors, refinements, and validators

### Changed
- Field validation now accepts optional `context:` parameter
- Schema `safe_parse` and `parse` now accept optional `context:` parameter
- Validators can now receive context as second argument

## [0.3.0] - 2024-01-14

### Added
- **Preprocessing** - `preprocess:` option for transforming input before validation
- **Conditional validation** - `when:` and `unless:` options for conditional field validation
- **Union types** - Accept multiple types with `union:` option
- **Coercion modes** - Disable coercion per-field with `coerce: false`
- **I18n support** - Internationalized error messages with locale switching
- `Validrb::I18n` module with `add_translations`, `locale`, and `reset!`

### Changed
- Validation pipeline now: preprocess -> coerce -> constraints -> transform
- Conditional fields are skipped when condition is false (treated as optional)

## [0.2.0] - 2024-01-13

### Added
- **Custom validators** - Cross-field validation with `validate` blocks
- **Custom error messages** - `message:` option for fields
- **Date/DateTime/Time types** - Full temporal type support with coercion
- **Decimal type** - BigDecimal support for precise numeric values
- **Schema composition** - `extend`, `merge`, `pick`, `omit`, `partial` methods
- **Unknown key handling** - `strict:` and `passthrough:` schema options
- **Transforms** - `transform:` option for post-validation transformation
- **Nullable fields** - `nullable:` option (distinct from `optional:`)
- ValidatorContext class for custom validators with `error` and `base_error` methods

### Changed
- Schema now supports composition methods for building derived schemas
- Error paths now support nested structures correctly

## [0.1.0] - 2024-01-12

### Added
- Initial release
- **Core types** - string, integer, float, boolean, array, object
- **Type coercion** - Automatic conversion between compatible types
- **Constraints** - min, max, length, format, enum
- **Schema DSL** - `Validrb.schema` with `field` declarations
- **Parsing methods** - `parse` (raises) and `safe_parse` (returns Result)
- **Result types** - `Success` and `Failure` with data/errors
- **Error tracking** - Path-tracked errors with ErrorCollection
- **Named formats** - email, url, uuid, phone, alphanumeric, alpha, numeric, hex, slug
- **Nested validation** - Objects and arrays with item/schema validation
- **Field options** - optional, default, nullable
- Zero runtime dependencies

### Notes
- Requires Ruby >= 3.0
- Inspired by Pydantic (Python) and Zod (TypeScript)

[0.6.0]: https://github.com/validrb/validrb/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/validrb/validrb/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/validrb/validrb/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/validrb/validrb/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/validrb/validrb/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/validrb/validrb/releases/tag/v0.1.0
