#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/validrb"

puts "=" * 60
puts "  VALIDRB DEMO - All Features"
puts "  Version: #{Validrb::VERSION}"
puts "=" * 60

# =============================================================================
# BASIC TYPES
# =============================================================================

puts "\n" + "=" * 60
puts "  BASIC TYPES"
puts "=" * 60

puts "\n1. String Type"
puts "-" * 40
schema = Validrb.schema do
  field :name, :string
end
result = schema.parse({ name: "John" })
puts "   Input:  { name: 'John' }"
puts "   Output: #{result}"

result = schema.parse({ name: :symbol_value })
puts "   Input:  { name: :symbol_value }"
puts "   Output: #{result}  (coerced from Symbol)"

puts "\n2. Integer Type"
puts "-" * 40
schema = Validrb.schema do
  field :age, :integer
end
result = schema.parse({ age: "25" })
puts "   Input:  { age: '25' }"
puts "   Output: #{result}  (coerced from String)"

result = schema.parse({ age: 30.0 })
puts "   Input:  { age: 30.0 }"
puts "   Output: #{result}  (coerced from Float)"

puts "\n3. Float Type"
puts "-" * 40
schema = Validrb.schema do
  field :price, :float
end
result = schema.parse({ price: "19.99" })
puts "   Input:  { price: '19.99' }"
puts "   Output: #{result}  (coerced from String)"

puts "\n4. Boolean Type"
puts "-" * 40
schema = Validrb.schema do
  field :active, :boolean
end

[true, "true", "yes", "on", "1", 1].each do |val|
  result = schema.parse({ active: val })
  puts "   Input:  { active: #{val.inspect} } => #{result[:active]}"
end

puts "\n5. Decimal Type (BigDecimal)"
puts "-" * 40
schema = Validrb.schema do
  field :amount, :decimal
end
result = schema.parse({ amount: "123.456789" })
puts "   Input:  { amount: '123.456789' }"
puts "   Output: #{result[:amount].class} -> #{result[:amount]}"

# Precision demo
a = result[:amount]
puts "   Precision test: #{a} * 3 = #{a * 3}"

puts "\n6. Date Type"
puts "-" * 40
schema = Validrb.schema do
  field :birth_date, :date
end
result = schema.parse({ birth_date: "1990-05-15" })
puts "   Input:  { birth_date: '1990-05-15' }"
puts "   Output: #{result[:birth_date].class} -> #{result[:birth_date]}"

# From timestamp
result = schema.parse({ birth_date: Time.new(2000, 1, 1).to_i })
puts "   Input:  { birth_date: <timestamp> }"
puts "   Output: #{result[:birth_date]}"

puts "\n7. DateTime Type"
puts "-" * 40
schema = Validrb.schema do
  field :created_at, :datetime
end
result = schema.parse({ created_at: "2024-01-15T12:30:00Z" })
puts "   Input:  { created_at: '2024-01-15T12:30:00Z' }"
puts "   Output: #{result[:created_at].class}"
puts "           #{result[:created_at]}"

puts "\n8. Time Type"
puts "-" * 40
schema = Validrb.schema do
  field :timestamp, :time
end
result = schema.parse({ timestamp: Time.now.to_i })
puts "   Input:  { timestamp: <unix_timestamp> }"
puts "   Output: #{result[:timestamp].class} -> #{result[:timestamp]}"

puts "\n9. Array Type"
puts "-" * 40
schema = Validrb.schema do
  field :tags, :array, of: :string
end
result = schema.parse({ tags: [:ruby, :rails, :api] })
puts "   Input:  { tags: [:ruby, :rails, :api] }"
puts "   Output: #{result}  (symbols coerced to strings)"

schema = Validrb.schema do
  field :scores, :array, of: :integer
end
result = schema.parse({ scores: ["100", "95", "87"] })
puts "   Input:  { scores: ['100', '95', '87'] }"
puts "   Output: #{result}  (strings coerced to integers)"

puts "\n10. Object Type (Nested Schema)"
puts "-" * 40
AddressSchema = Validrb.schema do
  field :street, :string
  field :city, :string
  field :zip, :string
end

UserSchema = Validrb.schema do
  field :name, :string
  field :address, :object, schema: AddressSchema
end

result = UserSchema.parse({
  name: "John",
  address: { street: "123 Main St", city: "Boston", zip: "02101" }
})
puts "   Nested schema validation:"
puts "   #{result}"

# =============================================================================
# CONSTRAINTS
# =============================================================================

puts "\n" + "=" * 60
puts "  CONSTRAINTS"
puts "=" * 60

puts "\n1. Min/Max (Numbers)"
puts "-" * 40
schema = Validrb.schema do
  field :age, :integer, min: 0, max: 150
end
result = schema.safe_parse({ age: 25 })
puts "   { age: 25 } with min: 0, max: 150"
puts "   Valid: #{result.success?}"

result = schema.safe_parse({ age: -5 })
puts "   { age: -5 } with min: 0"
puts "   Valid: #{result.success?}, Error: #{result.errors.first&.message}"

puts "\n2. Min/Max (Strings = Length)"
puts "-" * 40
schema = Validrb.schema do
  field :username, :string, min: 3, max: 20
end
result = schema.safe_parse({ username: "ab" })
puts "   { username: 'ab' } with min: 3"
puts "   Valid: #{result.success?}, Error: #{result.errors.first&.message}"

puts "\n3. Length Constraint"
puts "-" * 40
schema = Validrb.schema do
  field :pin, :string, length: 4
end
result = schema.safe_parse({ pin: "1234" })
puts "   { pin: '1234' } with length: 4"
puts "   Valid: #{result.success?}"

result = schema.safe_parse({ pin: "123" })
puts "   { pin: '123' } with length: 4"
puts "   Valid: #{result.success?}, Error: #{result.errors.first&.message}"

schema = Validrb.schema do
  field :password, :string, length: 8..32
end
result = schema.safe_parse({ password: "short" })
puts "   { password: 'short' } with length: 8..32"
puts "   Valid: #{result.success?}, Error: #{result.errors.first&.message}"

puts "\n4. Format Constraint"
puts "-" * 40
schema = Validrb.schema do
  field :email, :string, format: :email
  field :website, :string, format: :url
  field :id, :string, format: :uuid
end

result = schema.safe_parse({
  email: "user@example.com",
  website: "https://example.com",
  id: "550e8400-e29b-41d4-a716-446655440000"
})
puts "   Valid email, url, uuid: #{result.success?}"

result = schema.safe_parse({
  email: "invalid-email",
  website: "not-a-url",
  id: "not-a-uuid"
})
puts "   Invalid formats - Errors:"
result.errors.each { |e| puts "     - #{e.path.first}: #{e.message}" }

puts "\n   Available formats: :email, :url, :uuid, :phone, :alphanumeric,"
puts "                      :alpha, :numeric, :hex, :slug"

puts "\n5. Enum Constraint"
puts "-" * 40
schema = Validrb.schema do
  field :role, :string, enum: %w[admin user guest]
  field :priority, :integer, enum: [1, 2, 3]
end

result = schema.safe_parse({ role: "admin", priority: 1 })
puts "   { role: 'admin', priority: 1 }"
puts "   Valid: #{result.success?}"

result = schema.safe_parse({ role: "superuser", priority: 5 })
puts "   { role: 'superuser', priority: 5 }"
puts "   Errors:"
result.errors.each { |e| puts "     - #{e.path.first}: #{e.message}" }

puts "\n6. Custom Regex Format"
puts "-" * 40
schema = Validrb.schema do
  field :product_code, :string, format: /\A[A-Z]{2}-\d{4}\z/
end

result = schema.safe_parse({ product_code: "AB-1234" })
puts "   { product_code: 'AB-1234' } with /\\A[A-Z]{2}-\\d{4}\\z/"
puts "   Valid: #{result.success?}"

result = schema.safe_parse({ product_code: "invalid" })
puts "   { product_code: 'invalid' }"
puts "   Valid: #{result.success?}"

# =============================================================================
# FIELD OPTIONS
# =============================================================================

puts "\n" + "=" * 60
puts "  FIELD OPTIONS"
puts "=" * 60

puts "\n1. Optional Fields"
puts "-" * 40
schema = Validrb.schema do
  field :name, :string
  field :nickname, :string, optional: true
end

result = schema.parse({ name: "John" })
puts "   { name: 'John' } (nickname is optional)"
puts "   Output: #{result}"

puts "\n2. Default Values"
puts "-" * 40
schema = Validrb.schema do
  field :name, :string
  field :role, :string, default: "user"
  field :created_at, :datetime, default: -> { DateTime.now }
end

result = schema.parse({ name: "John" })
puts "   { name: 'John' } with role default: 'user'"
puts "   Output: #{result}"

puts "\n3. Nullable Fields"
puts "-" * 40
schema = Validrb.schema do
  field :name, :string
  field :deleted_at, :datetime, nullable: true
end

result = schema.parse({ name: "John", deleted_at: nil })
puts "   { name: 'John', deleted_at: nil } with nullable: true"
puts "   Output: #{result}"
puts "   (nullable accepts nil, optional accepts missing)"

puts "\n4. Transforms"
puts "-" * 40
schema = Validrb.schema do
  field :email, :string, transform: ->(v) { v.downcase.strip }
  field :tags, :string, transform: ->(v) { v.split(",").map(&:strip) }
end

result = schema.parse({ email: "  USER@EXAMPLE.COM  ", tags: "ruby, rails, api" })
puts "   Input:  { email: '  USER@EXAMPLE.COM  ', tags: 'ruby, rails, api' }"
puts "   Output: #{result}"

puts "\n5. Custom Error Messages"
puts "-" * 40
schema = Validrb.schema do
  field :age, :integer, min: 18, message: "You must be 18 years or older"
  field :email, :string, format: :email, message: "Please enter a valid email address"
end

result = schema.safe_parse({ age: 15, email: "invalid" })
puts "   Custom error messages:"
result.errors.each { |e| puts "     - #{e.path.first}: #{e.message}" }

# =============================================================================
# CUSTOM VALIDATORS
# =============================================================================

puts "\n" + "=" * 60
puts "  CUSTOM VALIDATORS"
puts "=" * 60

puts "\n1. Cross-Field Validation"
puts "-" * 40
schema = Validrb.schema do
  field :password, :string, min: 8
  field :password_confirmation, :string

  validate do |data|
    if data[:password] != data[:password_confirmation]
      error(:password_confirmation, "doesn't match password")
    end
  end
end

result = schema.safe_parse({
  password: "secretpassword",
  password_confirmation: "differentpassword"
})
puts "   Password mismatch validation:"
puts "   Error: #{result.errors.first&.full_path}: #{result.errors.first&.message}"

puts "\n2. Date Range Validation"
puts "-" * 40
schema = Validrb.schema do
  field :start_date, :date
  field :end_date, :date

  validate do |data|
    if data[:end_date] <= data[:start_date]
      error(:end_date, "must be after start date")
    end
  end
end

result = schema.safe_parse({
  start_date: "2024-01-15",
  end_date: "2024-01-10"
})
puts "   Date range validation (end before start):"
puts "   Error: #{result.errors.first&.message}"

puts "\n3. Base-Level Errors"
puts "-" * 40
schema = Validrb.schema do
  field :items, :array, of: :string

  validate do |data|
    base_error("At least one item is required") if data[:items].empty?
  end
end

result = schema.safe_parse({ items: [] })
puts "   Empty array validation:"
puts "   Error: #{result.errors.first&.message}"

puts "\n4. Multiple Validators"
puts "-" * 40
schema = Validrb.schema do
  field :username, :string, min: 3
  field :email, :string, format: :email

  validate do |data|
    if data[:username].downcase == "admin"
      error(:username, "cannot be 'admin'")
    end
  end

  validate do |data|
    if data[:email].end_with?("@test.com")
      error(:email, "test.com emails are not allowed")
    end
  end
end

result = schema.safe_parse({ username: "admin", email: "user@test.com" })
puts "   Multiple validators - Errors:"
result.errors.each { |e| puts "     - #{e.path.first}: #{e.message}" }

# =============================================================================
# SCHEMA OPTIONS
# =============================================================================

puts "\n" + "=" * 60
puts "  SCHEMA OPTIONS"
puts "=" * 60

puts "\n1. Strict Mode (Reject Unknown Keys)"
puts "-" * 40
schema = Validrb.schema(strict: true) do
  field :name, :string
end

result = schema.safe_parse({ name: "John", extra: "not allowed", another: 123 })
puts "   Input: { name: 'John', extra: 'not allowed', another: 123 }"
puts "   Errors:"
result.errors.each { |e| puts "     - #{e.path.first}: #{e.message}" }

puts "\n2. Passthrough Mode (Keep Unknown Keys)"
puts "-" * 40
schema = Validrb.schema(passthrough: true) do
  field :name, :string
end

result = schema.parse({ name: "John", extra: "kept", count: 42 })
puts "   Input:  { name: 'John', extra: 'kept', count: 42 }"
puts "   Output: #{result}"

puts "\n3. Default Mode (Strip Unknown Keys)"
puts "-" * 40
schema = Validrb.schema do
  field :name, :string
end

result = schema.parse({ name: "John", extra: "stripped" })
puts "   Input:  { name: 'John', extra: 'stripped' }"
puts "   Output: #{result}"

# =============================================================================
# SCHEMA COMPOSITION
# =============================================================================

puts "\n" + "=" * 60
puts "  SCHEMA COMPOSITION"
puts "=" * 60

puts "\n1. Extend"
puts "-" * 40
BaseSchema = Validrb.schema do
  field :id, :integer
  field :created_at, :datetime, default: -> { DateTime.now }
end

UserSchema2 = BaseSchema.extend do
  field :name, :string
  field :email, :string, format: :email
end

puts "   BaseSchema fields: #{BaseSchema.fields.keys}"
puts "   UserSchema fields: #{UserSchema2.fields.keys}"

result = UserSchema2.parse({ id: 1, name: "John", email: "john@example.com" })
puts "   Parsed: #{result.reject { |k, _| k == :created_at }}"

puts "\n2. Pick (Select Fields)"
puts "-" * 40
FullSchema = Validrb.schema do
  field :id, :integer
  field :name, :string
  field :email, :string
  field :password, :string
  field :role, :string
end

PublicSchema = FullSchema.pick(:id, :name, :email)
puts "   FullSchema fields: #{FullSchema.fields.keys}"
puts "   PublicSchema fields: #{PublicSchema.fields.keys}"

puts "\n3. Omit (Exclude Fields)"
puts "-" * 40
SafeSchema = FullSchema.omit(:password)
puts "   FullSchema fields: #{FullSchema.fields.keys}"
puts "   SafeSchema fields: #{SafeSchema.fields.keys}"

puts "\n4. Merge"
puts "-" * 40
Schema1 = Validrb.schema do
  field :name, :string
  field :age, :integer
end

Schema2 = Validrb.schema do
  field :email, :string
  field :age, :string  # Override with different type
end

MergedSchema = Schema1.merge(Schema2)
puts "   Schema1: #{Schema1.fields.keys} (age is integer)"
puts "   Schema2: #{Schema2.fields.keys} (age is string)"
puts "   Merged:  #{MergedSchema.fields.keys}"
puts "   Merged age type: #{MergedSchema.fields[:age].type.class}"

puts "\n5. Partial (All Fields Optional)"
puts "-" * 40
CreateSchema = Validrb.schema do
  field :name, :string
  field :email, :string
  field :age, :integer
end

UpdateSchema = CreateSchema.partial
puts "   CreateSchema - all required"
puts "   UpdateSchema - all optional (for PATCH updates)"

result = UpdateSchema.parse({ name: "John" })  # Only updating name
puts "   Partial update: #{result}"

# =============================================================================
# ERROR HANDLING
# =============================================================================

puts "\n" + "=" * 60
puts "  ERROR HANDLING"
puts "=" * 60

puts "\n1. parse() - Raises Exception"
puts "-" * 40
schema = Validrb.schema do
  field :name, :string
  field :age, :integer, min: 0
end

begin
  schema.parse({ name: "", age: -5 })
rescue Validrb::ValidationError => e
  puts "   Caught ValidationError:"
  puts "   Message: #{e.message}"
  puts "   Errors count: #{e.errors.size}"
end

puts "\n2. safe_parse() - Returns Result"
puts "-" * 40
result = schema.safe_parse({ name: "", age: -5 })
puts "   result.success? => #{result.success?}"
puts "   result.failure? => #{result.failure?}"
puts "   result.data     => #{result.data.inspect}"
puts "   result.errors   => ErrorCollection (#{result.errors.size} errors)"

puts "\n3. Error Details"
puts "-" * 40
result.errors.each do |error|
  puts "   Path:    #{error.path.inspect}"
  puts "   Message: #{error.message}"
  puts "   Code:    #{error.code}"
  puts "   Full:    #{error.to_s}"
  puts
end

puts "4. Error Collection Methods"
puts "-" * 40
puts "   errors.messages      => #{result.errors.messages}"
puts "   errors.full_messages => #{result.errors.full_messages}"
puts "   errors.to_h          => #{result.errors.to_h}"

puts "\n5. Nested Error Paths"
puts "-" * 40
OrderSchema = Validrb.schema do
  field :id, :integer
  field :items, :array, of: Validrb::Types::Object.new(
    schema: Validrb.schema do
      field :name, :string, min: 1
      field :quantity, :integer, min: 1
    end
  )
end

result = OrderSchema.safe_parse({
  id: 1,
  items: [
    { name: "Widget", quantity: 2 },
    { name: "", quantity: 0 }
  ]
})
puts "   Nested validation errors:"
result.errors.each do |error|
  puts "   - #{error.path.inspect}: #{error.message}"
end

# =============================================================================
# REAL-WORLD EXAMPLE
# =============================================================================

puts "\n" + "=" * 60
puts "  REAL-WORLD EXAMPLE: User Registration"
puts "=" * 60

# Note: Transforms run AFTER validation, so use them for output formatting,
# not input sanitization. For input cleanup, sanitize before calling parse().

RegistrationSchema = Validrb.schema(strict: true) do
  field :username, :string, min: 3, max: 20, format: :alphanumeric,
        transform: ->(v) { v.downcase }
  field :email, :string, format: :email,
        transform: ->(v) { v.downcase }  # Normalize to lowercase
  field :password, :string, min: 8
  field :password_confirmation, :string
  field :age, :integer, min: 13, message: "You must be at least 13 years old"
  field :newsletter, :boolean, default: false
  field :referral_code, :string, optional: true, format: /\A[A-Z0-9]{6}\z/

  validate do |data|
    if data[:password] != data[:password_confirmation]
      error(:password_confirmation, "doesn't match password")
    end
  end

  validate do |data|
    reserved = %w[admin root system]
    if reserved.include?(data[:username].downcase)
      error(:username, "is reserved")
    end
  end
end

puts "\n1. Valid Registration"
puts "-" * 40
result = RegistrationSchema.safe_parse({
  username: "JohnDoe",
  email: "JOHN@EXAMPLE.COM",
  password: "secretpassword123",
  password_confirmation: "secretpassword123",
  age: "25",
  referral_code: "ABC123"
})
puts "   Success: #{result.success?}"
if result.success?
  puts "   Data:"
  result.data.each { |k, v| puts "     #{k}: #{v.inspect}" }
else
  puts "   Errors:"
  result.errors.each { |e| puts "   - #{e}" }
end

puts "\n2. Invalid Registration"
puts "-" * 40
result = RegistrationSchema.safe_parse({
  username: "admin",
  email: "invalid-email",
  password: "short",
  password_confirmation: "different",
  age: 10,
  newsletter: "yes",
  extra_field: "not allowed"
})
puts "   Success: #{result.success?}"
puts "   Errors:"
result.errors.each { |e| puts "   - #{e}" }

puts "\n" + "=" * 60
puts "  DEMO COMPLETE"
puts "=" * 60
