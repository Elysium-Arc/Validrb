# Validrb

A powerful Ruby schema validation library with type coercion, inspired by Pydantic and Zod. Define schemas once, validate data with automatic type coercion, generate JSON Schema, and serialize results.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-ruby.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Type Coercion** - Automatic conversion of strings to integers, booleans, dates, etc.
- **Rich Constraints** - min/max, length, format, enum, and custom validations
- **Schema Composition** - Extend, merge, pick, omit, and partial schemas
- **Nested Validation** - Deep validation of objects and arrays
- **Union Types** - Accept multiple types for a single field
- **Discriminated Unions** - Polymorphic data with type discriminators
- **Conditional Validation** - Validate fields based on other field values
- **Custom Types** - Define your own types with custom coercion
- **I18n Support** - Internationalized error messages
- **JSON Schema Generation** - Export schemas to JSON Schema format
- **Serialization** - Convert validated data to JSON-ready primitives
- **Rails Integration** - Form objects, controller helpers, and ActiveRecord support

## Installation

Add to your Gemfile:

```ruby
gem 'validrb'
```

Or install directly:

```bash
gem install validrb
```

## Quick Start

```ruby
require 'validrb'

# Define a schema
UserSchema = Validrb.schema do
  field :name, :string, min: 1, max: 100
  field :email, :string, format: :email
  field :age, :integer, min: 0, optional: true
  field :role, :string, enum: %w[admin user guest], default: "user"
end

# Parse with automatic coercion
result = UserSchema.safe_parse({
  name: "John Doe",
  email: "john@example.com",
  age: "25"  # String automatically coerced to integer
})

if result.success?
  puts result.data  # => { name: "John Doe", email: "john@example.com", age: 25, role: "user" }
else
  puts result.errors.full_messages
end

# Or raise on failure
user = UserSchema.parse(params)  # Raises Validrb::ValidationError on failure
```

## Table of Contents

- [Types](#types)
- [Constraints](#constraints)
- [Field Options](#field-options)
- [Schema Options](#schema-options)
- [Schema Composition](#schema-composition)
- [Custom Validators](#custom-validators)
- [Conditional Validation](#conditional-validation)
- [Union Types](#union-types)
- [Discriminated Unions](#discriminated-unions)
- [Refinements](#refinements)
- [Validation Context](#validation-context)
- [Custom Types](#custom-types)
- [Serialization](#serialization)
- [JSON Schema Generation](#json-schema-generation)
- [Schema Introspection](#schema-introspection)
- [I18n Support](#i18n-support)
- [Error Handling](#error-handling)

## Types

### Built-in Types

| Type | Ruby Class | Coerces From |
|------|------------|--------------|
| `:string` | String | Symbol, Numeric |
| `:integer` | Integer | String, Float (whole numbers) |
| `:float` | Float | String, Integer |
| `:boolean` | TrueClass/FalseClass | "true"/"false", "yes"/"no", "1"/"0", 1/0 |
| `:decimal` | BigDecimal | String, Integer, Float |
| `:date` | Date | ISO8601 String, DateTime, Time, Unix timestamp |
| `:datetime` | DateTime | ISO8601 String, Date, Time, Unix timestamp |
| `:time` | Time | ISO8601 String, DateTime, Date, Unix timestamp |
| `:array` | Array | (validates items with `of:` option) |
| `:object` | Hash | (validates with nested `schema:`) |

### Type Examples

```ruby
schema = Validrb.schema do
  # Basic types
  field :name, :string
  field :count, :integer
  field :price, :float
  field :active, :boolean

  # Precise decimals
  field :amount, :decimal

  # Date/time types
  field :birth_date, :date
  field :created_at, :datetime
  field :timestamp, :time

  # Arrays with typed items
  field :tags, :array, of: :string
  field :scores, :array, of: :integer

  # Nested objects
  field :address, :object, schema: AddressSchema
end
```

### Inline Nested Schemas (v0.6.0+)

Define nested schemas directly without creating separate schema objects:

```ruby
schema = Validrb.schema do
  field :name, :string

  # Inline object schema
  field :address, :object do
    field :street, :string
    field :city, :string
    field :zip, :string, format: /\A\d{5}\z/
  end

  # Inline array item schema
  field :items, :array do
    field :product_id, :integer
    field :quantity, :integer, min: 1
  end
end
```

### Array of Schemas Shorthand (v0.6.0+)

Pass schema instances directly to `of:`:

```ruby
ItemSchema = Validrb.schema do
  field :id, :integer
  field :name, :string
end

schema = Validrb.schema do
  # Pass schema directly - no wrapper needed
  field :items, :array, of: ItemSchema
end
```

## Constraints

```ruby
schema = Validrb.schema do
  # Numeric min/max
  field :age, :integer, min: 0, max: 150
  field :price, :float, min: 0.01

  # String length (min/max applied to length)
  field :username, :string, min: 3, max: 20

  # Exact length
  field :pin, :string, length: 4

  # Length range
  field :password, :string, length: 8..128

  # Length with options
  field :bio, :string, length: { min: 10, max: 500 }

  # Named formats
  field :email, :string, format: :email
  field :website, :string, format: :url
  field :id, :string, format: :uuid

  # Custom regex
  field :code, :string, format: /\A[A-Z]{2}-\d{4}\z/

  # Enum (allowed values)
  field :status, :string, enum: %w[pending active completed]
  field :priority, :integer, enum: [1, 2, 3]
end
```

### Available Formats

`:email`, `:url`, `:uuid`, `:phone`, `:alphanumeric`, `:alpha`, `:numeric`, `:hex`, `:slug`

## Field Options

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
| `literal` | Array | Accept only exact values |
| `refine` | Proc/Array | Custom validation predicates |

### Examples

```ruby
schema = Validrb.schema do
  # Optional field
  field :nickname, :string, optional: true

  # Nullable field (accepts nil)
  field :deleted_at, :datetime, nullable: true

  # Default values
  field :role, :string, default: "user"
  field :created_at, :datetime, default: -> { DateTime.now }

  # Preprocessing (runs BEFORE validation)
  field :email, :string, format: :email,
        preprocess: ->(v) { v.to_s.strip.downcase }

  # Transform (runs AFTER validation)
  field :tags, :string, transform: ->(v) { v.split(",").map(&:strip) }

  # Disable coercion (strict type checking)
  field :count, :integer, coerce: false

  # Custom error message
  field :age, :integer, min: 18, message: "Must be 18 or older"
end
```

## Schema Options

```ruby
# Strict mode - reject unknown keys
schema = Validrb.schema(strict: true) do
  field :name, :string
end

schema.safe_parse({ name: "John", extra: "rejected" })
# => Failure with error on :extra

# Passthrough mode - keep unknown keys
schema = Validrb.schema(passthrough: true) do
  field :name, :string
end

schema.parse({ name: "John", extra: "kept" })
# => { name: "John", extra: "kept" }
```

## Schema Composition

```ruby
BaseSchema = Validrb.schema do
  field :id, :integer
  field :created_at, :datetime, default: -> { DateTime.now }
end

# Extend with additional fields
UserSchema = BaseSchema.extend do
  field :name, :string
  field :email, :string, format: :email
end

# Pick specific fields
PublicUserSchema = UserSchema.pick(:id, :name)

# Omit specific fields
SafeUserSchema = UserSchema.omit(:password)

# Merge two schemas (second takes precedence)
MergedSchema = Schema1.merge(Schema2)

# Make all fields optional (useful for PATCH updates)
UpdateSchema = UserSchema.partial
```

## Custom Validators

```ruby
schema = Validrb.schema do
  field :password, :string, min: 8
  field :password_confirmation, :string

  # Cross-field validation
  validate do |data|
    if data[:password] != data[:password_confirmation]
      error(:password_confirmation, "doesn't match password")
    end
  end

  # Base-level errors (not tied to a field)
  validate do |data|
    if data[:items]&.empty?
      base_error("At least one item is required")
    end
  end
end
```

## Conditional Validation

```ruby
schema = Validrb.schema do
  field :account_type, :string, enum: %w[personal business]

  # Validate only when condition is true
  field :company_name, :string,
        when: ->(data) { data[:account_type] == "business" }

  # Validate unless condition is true
  field :personal_id, :string,
        unless: ->(data) { data[:account_type] == "business" }

  # Symbol shorthand (checks if field is truthy)
  field :subscribe, :boolean, default: false
  field :email, :string, format: :email, when: :subscribe
end
```

## Union Types

```ruby
schema = Validrb.schema do
  # Accept multiple types (tries in order, put specific types first)
  field :id, :string, union: [:integer, :string]
end

schema.parse({ id: 123 })      # => { id: 123 }
schema.parse({ id: "abc-123" }) # => { id: "abc-123" }
schema.parse({ id: "456" })     # => { id: 456 } (coerced to integer)
```

## Discriminated Unions

For polymorphic data, use discriminated unions to select the right schema based on a discriminator field:

```ruby
CreditCardSchema = Validrb.schema do
  field :type, :string
  field :card_number, :string
  field :expiry, :string
end

PayPalSchema = Validrb.schema do
  field :type, :string
  field :email, :string, format: :email
end

PaymentSchema = Validrb.schema do
  field :payment, :discriminated_union,
        discriminator: :type,
        mapping: {
          "credit_card" => CreditCardSchema,
          "paypal" => PayPalSchema
        }
end

PaymentSchema.parse({
  payment: { type: "credit_card", card_number: "4111...", expiry: "12/25" }
})

PaymentSchema.parse({
  payment: { type: "paypal", email: "user@example.com" }
})
```

## Refinements

Add custom validation predicates beyond built-in constraints:

```ruby
schema = Validrb.schema do
  # Simple refinement
  field :age, :integer, refine: ->(v) { v >= 18 }

  # With custom message
  field :password, :string,
        refine: {
          check: ->(v) { v.match?(/[A-Z]/) },
          message: "must contain an uppercase letter"
        }

  # Multiple refinements
  field :code, :string,
        refine: [
          { check: ->(v) { v.length >= 8 }, message: "too short" },
          { check: ->(v) { v.match?(/\d/) }, message: "needs a digit" },
          { check: ->(v) { v.match?(/[A-Z]/) }, message: "needs uppercase" }
        ]
end
```

## Validation Context

Pass request-level data through the validation pipeline:

```ruby
schema = Validrb.schema do
  field :amount, :decimal,
        refine: ->(value, ctx) {
          ctx.nil? || value <= ctx[:max_amount]
        }

  field :admin_only, :string,
        when: ->(data, ctx) { ctx && ctx[:is_admin] }

  validate do |data, ctx|
    if ctx && ctx[:restricted] && data[:amount] > 100
      error(:amount, "exceeds limit in restricted mode")
    end
  end
end

# Create and pass context
ctx = Validrb.context(max_amount: 1000, is_admin: true)
result = schema.safe_parse(data, context: ctx)
```

## Custom Types

Define your own types with custom coercion and validation:

```ruby
Validrb.define_type(:money) do
  coerce { |v| BigDecimal(v.to_s.gsub(/[$,]/, "")) }
  validate { |v| v >= 0 }
  error_message { "must be a valid money amount" }
end

Validrb.define_type(:slug) do
  coerce { |v| v.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "") }
  validate { |v| v.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) }
end

schema = Validrb.schema do
  field :price, :money
  field :url_slug, :slug
end

schema.parse({ price: "$1,234.56", url_slug: "Hello World!" })
# => { price: #<BigDecimal:1234.56>, url_slug: "hello-world" }
```

## Serialization

Convert validated data to JSON-ready primitives:

```ruby
schema = Validrb.schema do
  field :name, :string
  field :created_at, :date
  field :amount, :decimal
end

result = schema.safe_parse({
  name: "Test",
  created_at: "2024-01-15",
  amount: "99.99"
})

# Serialize to hash with primitives
result.dump
# => { "name" => "Test", "created_at" => "2024-01-15", "amount" => "99.99" }

# Serialize to JSON
result.to_json
# => '{"name":"Test","created_at":"2024-01-15","amount":"99.99"}'

# Schema-level dump (parse + serialize)
schema.dump(data)           # Raises on validation error
schema.safe_dump(data)      # Returns Result
```

## JSON Schema Generation

Generate JSON Schema from your Validrb schemas:

```ruby
schema = Validrb.schema do
  field :id, :integer
  field :name, :string, min: 1, max: 100
  field :email, :string, format: :email
  field :age, :integer, optional: true, min: 0
  field :role, :string, enum: %w[admin user], default: "user"
end

json_schema = schema.to_json_schema
# => {
#   "$schema" => "https://json-schema.org/draft-07/schema#",
#   "type" => "object",
#   "required" => ["id", "name", "email"],
#   "properties" => {
#     "id" => { "type" => "integer" },
#     "name" => { "type" => "string", "minLength" => 1, "maxLength" => 100 },
#     "email" => { "type" => "string" },
#     "age" => { "type" => "integer", "minimum" => 0 },
#     "role" => { "type" => "string", "enum" => ["admin", "user"], "default" => "user" }
#   }
# }
```

## Rails Integration

Validrb integrates seamlessly with Rails applications, providing form objects, controller helpers, and ActiveRecord validation.

### Setup

```ruby
# Gemfile
gem 'validrb'

# config/initializers/validrb.rb (optional - auto-configured with Railtie)
require 'validrb/rails'
```

### Form Objects

Create form objects that work with Rails form helpers:

```ruby
class UserForm < Validrb::Rails::FormObject
  schema do
    field :name, :string, min: 2, max: 100
    field :email, :string, format: :email
    field :age, :integer, optional: true
    field :newsletter, :boolean, default: false
  end
end

# In controller
def new
  @user_form = UserForm.new
end

def create
  @user_form = UserForm.new(user_params)
  if @user_form.valid?
    User.create!(@user_form.attributes)
    redirect_to users_path
  else
    render :new, status: :unprocessable_entity
  end
end

private

def user_params
  params.require(:user).permit(:name, :email, :age, :newsletter)
end
```

```erb
<%# Works with Rails form helpers %>
<%= form_with model: @user_form, url: users_path do |f| %>
  <% if @user_form.errors.any? %>
    <div class="errors">
      <% @user_form.errors.full_messages.each do |msg| %>
        <p><%= msg %></p>
      <% end %>
    </div>
  <% end %>

  <%= f.text_field :name %>
  <%= f.email_field :email %>
  <%= f.number_field :age %>
  <%= f.check_box :newsletter %>
  <%= f.submit %>
<% end %>
```

### Controller Helpers

Validate params directly in controllers:

```ruby
class UsersController < ApplicationController
  include Validrb::Rails::Controller  # Auto-included with Railtie

  UserSchema = Validrb.schema do
    field :name, :string, min: 2
    field :email, :string, format: :email
  end

  def create
    # Returns Validrb::Result
    result = validate_params(UserSchema, :user)

    if result.success?
      @user = User.create!(result.data)
      redirect_to @user
    else
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end

  # Or use validate_params! which raises on failure
  def update
    data = validate_params!(UserSchema, :user)
    @user.update!(data)
    redirect_to @user
  rescue Validrb::Rails::Controller::ValidationError => e
    @errors = e.errors
    render :edit, status: :unprocessable_entity
  end
end
```

### ActiveRecord Integration

Add schema validation to ActiveRecord models:

```ruby
class User < ApplicationRecord
  include Validrb::Rails::Model

  validates_with_schema do
    field :name, :string, min: 2, max: 100
    field :email, :string, format: :email
    field :age, :integer, min: 0, optional: true
  end
end

# Or use an existing schema
class User < ApplicationRecord
  include Validrb::Rails::Model

  validates_with_schema UserSchema, only: [:name, :email]
end
```

## OpenAPI 3.0 Generation

Generate complete OpenAPI 3.0 specifications from your schemas:

```ruby
# Create an OpenAPI generator
generator = Validrb::OpenAPI.generator

# Register schemas
generator.register("User", UserSchema)
generator.register("CreateUser", CreateUserSchema)

# Build paths
paths = Validrb::OpenAPI::PathBuilder.new(generator)
  .get("/users", summary: "List users")
  .post("/users", schema: CreateUserSchema, summary: "Create user")
  .get("/users/{id}", summary: "Get user")
  .put("/users/{id}", schema: UpdateUserSchema, summary: "Update user")
  .to_h

# Generate the OpenAPI document
doc = generator.generate(
  info: {
    title: "My API",
    version: "1.0.0",
    description: "API documentation"
  },
  servers: ["https://api.example.com"],
  paths: paths
)

# Export as JSON or YAML
puts generator.to_json(info: { title: "My API", version: "1.0.0" })
puts generator.to_yaml(info: { title: "My API", version: "1.0.0" })
```

### Import from OpenAPI/JSON Schema

Create Validrb schemas from existing OpenAPI or JSON Schema definitions:

```ruby
# Import from OpenAPI document
openapi_doc = JSON.parse(File.read("openapi.json"))
importer = Validrb::OpenAPI.import(openapi_doc)

# Access imported schemas
user_schema = importer["User"]
post_schema = importer["Post"]

# Use for validation
result = user_schema.safe_parse(params)

# Import a single JSON Schema
json_schema = {
  "type" => "object",
  "properties" => {
    "name" => { "type" => "string", "minLength" => 1 },
    "age" => { "type" => "integer", "minimum" => 0 }
  },
  "required" => ["name"]
}

schema = Validrb::OpenAPI.import_schema(json_schema)
schema.parse({ name: "John", age: 25 })
```

## Schema Introspection

Inspect schema structure programmatically:

```ruby
schema.field_names          # => [:id, :name, :email, :age, :role]
schema.required_fields      # => [:id, :name, :email]
schema.optional_fields      # => [:age]
schema.fields_with_defaults # => [:role]
schema.conditional_fields   # => []

# Get field details
field = schema.field(:name)
field.type.type_name        # => "string"
field.constraint_values     # => { min: 1, max: 100 }
field.optional?             # => false
```

## I18n Support

Customize error messages with internationalization:

```ruby
# Add custom translations
Validrb::I18n.add_translations(:en,
  required: "cannot be blank",
  min: "must be at least %{value}"
)

# Switch locale
Validrb::I18n.add_translations(:es,
  required: "es requerido",
  min: "debe ser al menos %{value}"
)
Validrb::I18n.locale = :es

# Reset to defaults
Validrb::I18n.reset!
```

## Error Handling

```ruby
# safe_parse returns a Result object
result = schema.safe_parse(data)

result.success?  # => true/false
result.failure?  # => true/false
result.data      # => validated data (if success)
result.errors    # => ErrorCollection (if failure)

# Error details
result.errors.each do |error|
  error.path      # => [:user, :email]
  error.message   # => "must be a valid email"
  error.code      # => :format
  error.to_s      # => "user.email must be a valid email"
end

# Error collection methods
result.errors.messages       # => ["must be a valid email", ...]
result.errors.full_messages  # => ["user.email must be a valid email", ...]
result.errors.to_h           # => { [:user, :email] => ["must be a valid email"] }

# parse raises on failure
begin
  schema.parse(invalid_data)
rescue Validrb::ValidationError => e
  e.errors  # => ErrorCollection
  e.message # => Summary of errors
end
```

## Requirements

- Ruby >= 3.0
- No runtime dependencies

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run demo
bundle exec ruby demo.rb
```

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

Inspired by [Pydantic](https://pydantic.dev/) (Python) and [Zod](https://zod.dev/) (TypeScript).
