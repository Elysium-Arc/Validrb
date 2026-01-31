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

# =============================================================================
# PHASE 3 FEATURES
# =============================================================================

puts "\n" + "=" * 60
puts "  PHASE 3 FEATURES"
puts "=" * 60

puts "\n1. Preprocessing (runs BEFORE validation)"
puts "-" * 40
schema = Validrb.schema do
  field :email, :string, format: :email, preprocess: ->(v) { v.to_s.strip.downcase }
  field :code, :string, format: /\A[A-Z]+\z/, preprocess: ->(v) { v.upcase }
end

result = schema.parse({ email: "  USER@EXAMPLE.COM  ", code: "abc" })
puts "   Input:  { email: '  USER@EXAMPLE.COM  ', code: 'abc' }"
puts "   Output: #{result}"
puts "   (preprocess runs before format validation)"

puts "\n2. Conditional Validation (when:)"
puts "-" * 40
schema = Validrb.schema do
  field :account_type, :string, enum: %w[personal business]
  field :company_name, :string, when: ->(d) { d[:account_type] == "business" }
end

result = schema.safe_parse({ account_type: "personal" })
puts "   Personal account (no company needed):"
puts "   Success: #{result.success?}, Data: #{result.data}"

result = schema.safe_parse({ account_type: "business" })
puts "   Business account (company required):"
puts "   Success: #{result.success?}, Error: #{result.errors.first&.message}"

result = schema.safe_parse({ account_type: "business", company_name: "Acme Inc" })
puts "   Business with company:"
puts "   Success: #{result.success?}, Data: #{result.data}"

puts "\n3. Conditional Validation (unless:)"
puts "-" * 40
schema = Validrb.schema do
  field :use_default, :boolean, default: false
  field :custom_value, :string, unless: :use_default
end

result = schema.safe_parse({ use_default: true })
puts "   Using default (custom_value not required):"
puts "   Success: #{result.success?}"

result = schema.safe_parse({ use_default: false })
puts "   Not using default (custom_value required):"
puts "   Success: #{result.success?}, Error: #{result.errors.first&.message}"

puts "\n4. Union Types"
puts "-" * 40
schema = Validrb.schema do
  # Note: Put more specific types first (integer before string)
  field :id, :string, union: [:integer, :string]
end

result = schema.parse({ id: 12345 })
puts "   Input:  { id: 12345 }"
puts "   Output: #{result}  (matched integer)"

result = schema.parse({ id: "abc-123" })
puts "   Input:  { id: 'abc-123' }"
puts "   Output: #{result}  (matched string)"

result = schema.parse({ id: "42" })
puts "   Input:  { id: '42' }"
puts "   Output: #{result}  (coerced to integer - first match)"

puts "\n5. Coercion Modes"
puts "-" * 40
schema = Validrb.schema do
  field :strict_count, :integer, coerce: false
  field :flexible_count, :integer  # coerce: true (default)
end

result = schema.safe_parse({ strict_count: 42, flexible_count: "42" })
puts "   With actual integer and string:"
puts "   Success: #{result.success?}, Data: #{result.data}"

result = schema.safe_parse({ strict_count: "42", flexible_count: "42" })
puts "   With strings for both:"
puts "   Success: #{result.success?}"
puts "   Error: #{result.errors.first&.path&.first}: #{result.errors.first&.message}"

puts "\n6. I18n Support"
puts "-" * 40
# Save original state
original_locale = Validrb::I18n.locale

# Add Spanish translations
Validrb::I18n.add_translations(:es, required: "es requerido")
Validrb::I18n.locale = :es

schema = Validrb.schema do
  field :nombre, :string
end

result = schema.safe_parse({})
puts "   Spanish locale:"
puts "   Error: #{result.errors.first&.message}"

# Reset to English
Validrb::I18n.reset!

puts "\n7. Complete Phase 3 Example: Dynamic Form"
puts "-" * 40
DynamicFormSchema = Validrb.schema do
  field :form_type, :string, enum: %w[contact support order]

  # Contact: requires name and email
  field :name, :string,
        preprocess: ->(v) { v&.strip },
        when: ->(d) { d[:form_type] == "contact" }

  # Contact & Support: requires email
  field :email, :string, format: :email,
        preprocess: ->(v) { v&.strip&.downcase },
        when: ->(d) { %w[contact support].include?(d[:form_type]) }

  # Support: requires ticket_id
  field :ticket_id, :string, format: /\ATKT-\d+\z/,
        when: ->(d) { d[:form_type] == "support" }

  # Order: requires order_id (can be string or integer)
  field :order_id, :string, union: [:integer, :string],
        when: ->(d) { d[:form_type] == "order" }
end

puts "   Contact form:"
result = DynamicFormSchema.safe_parse({
  form_type: "contact",
  name: "  John Doe  ",
  email: "  JOHN@EXAMPLE.COM  "
})
puts "   Success: #{result.success?}"
puts "   Data: #{result.data}" if result.success?

puts "\n   Support form:"
result = DynamicFormSchema.safe_parse({
  form_type: "support",
  email: "support@example.com",
  ticket_id: "TKT-12345"
})
puts "   Success: #{result.success?}"
puts "   Data: #{result.data}" if result.success?

puts "\n   Order form:"
result = DynamicFormSchema.safe_parse({
  form_type: "order",
  order_id: 99999
})
puts "   Success: #{result.success?}"
puts "   Data: #{result.data}" if result.success?

# =============================================================================
# PHASE 4 FEATURES
# =============================================================================

puts "\n" + "=" * 60
puts "  PHASE 4 FEATURES"
puts "=" * 60

puts "\n1. Literal Types"
puts "-" * 40
schema = Validrb.schema do
  field :status, :string, literal: %w[active pending completed]
  field :priority, :integer, literal: [1, 2, 3]
end

result = schema.safe_parse({ status: "active", priority: 2 })
puts "   Input:  { status: 'active', priority: 2 }"
puts "   Success: #{result.success?}"

result = schema.safe_parse({ status: "unknown", priority: 5 })
puts "   Input:  { status: 'unknown', priority: 5 }"
puts "   Success: #{result.success?}"
puts "   Errors: #{result.errors.map { |e| "#{e.path.first}: #{e.message}" }.join(", ")}"

puts "\n2. Refinements"
puts "-" * 40
schema = Validrb.schema do
  field :password, :string,
        refine: [
          { check: ->(v) { v.length >= 8 }, message: "must be at least 8 characters" },
          { check: ->(v) { v.match?(/[A-Z]/) }, message: "must contain uppercase letter" },
          { check: ->(v) { v.match?(/\d/) }, message: "must contain a digit" }
        ]
end

result = schema.safe_parse({ password: "SecurePass123" })
puts "   Password 'SecurePass123': #{result.success?}"

result = schema.safe_parse({ password: "weak" })
puts "   Password 'weak': #{result.success?}"
puts "   Error: #{result.errors.first&.message}"

puts "\n3. Validation Context"
puts "-" * 40
schema = Validrb.schema do
  field :amount, :decimal,
        refine: ->(v, ctx) { ctx.nil? || !ctx.key?(:max_amount) || v <= ctx[:max_amount] }

  validate do |data, ctx|
    if ctx && ctx[:restricted_mode] && data[:amount] > 100
      error(:amount, "cannot exceed 100 in restricted mode")
    end
  end
end

puts "   Without context:"
result = schema.safe_parse({ amount: "500" })
puts "   Amount 500: #{result.success?}"

puts "   With context (max_amount: 1000):"
result = schema.safe_parse({ amount: "500" }, context: { max_amount: 1000 })
puts "   Amount 500: #{result.success?}"

puts "   With context (restricted_mode: true):"
result = schema.safe_parse({ amount: "500" }, context: { restricted_mode: true })
puts "   Amount 500: #{result.success?}, Error: #{result.errors.first&.message}"

puts "\n4. Custom Types"
puts "-" * 40
# Define a custom money type
Validrb.define_type(:money) do
  coerce { |v| BigDecimal(v.to_s.gsub(/[$,]/, "")) }
  validate { |v| v >= 0 }
  error_message { "must be a valid non-negative money amount" }
end

schema = Validrb.schema do
  field :price, :money
end

result = schema.safe_parse({ price: "$1,234.56" })
puts "   Input:  { price: '$1,234.56' }"
puts "   Output: #{result.data[:price]} (#{result.data[:price].class})"

# Clean up
Validrb::Types.registry.delete(:money)

puts "\n5. Discriminated Unions"
puts "-" * 40
# Define schemas for different payment methods
CreditCardSchema = Validrb.schema do
  field :method, :string
  field :card_number, :string
  field :expiry, :string
end

PaypalSchema = Validrb.schema do
  field :method, :string
  field :email, :string, format: :email
end

PaymentSchema = Validrb.schema do
  field :payment, :discriminated_union,
        discriminator: :method,
        mapping: {
          "credit_card" => CreditCardSchema,
          "paypal" => PaypalSchema
        }
end

result = PaymentSchema.safe_parse({
  payment: { method: "credit_card", card_number: "4111111111111111", expiry: "12/25" }
})
puts "   Credit card payment: #{result.success?}"

result = PaymentSchema.safe_parse({
  payment: { method: "paypal", email: "user@example.com" }
})
puts "   PayPal payment: #{result.success?}"

result = PaymentSchema.safe_parse({
  payment: { method: "bitcoin", wallet: "abc123" }
})
puts "   Bitcoin (invalid): #{result.success?}"
puts "   Error: #{result.errors.first&.message}"

puts "\n6. Schema Introspection"
puts "-" * 40
IntrospectSchema = Validrb.schema do
  field :id, :integer
  field :name, :string, min: 1, max: 100
  field :email, :string, format: :email
  field :age, :integer, optional: true, min: 0
  field :role, :string, enum: %w[admin user], default: "user"
end

puts "   Field names:       #{IntrospectSchema.field_names}"
puts "   Required fields:   #{IntrospectSchema.required_fields}"
puts "   Optional fields:   #{IntrospectSchema.optional_fields}"
puts "   Fields w/defaults: #{IntrospectSchema.fields_with_defaults}"

# Field introspection
name_field = IntrospectSchema.field(:name)
puts "   Name field constraints: #{name_field.constraint_values}"

puts "\n7. JSON Schema Generation"
puts "-" * 40
json_schema = IntrospectSchema.to_json_schema
puts "   Generated JSON Schema:"
puts "   - type: #{json_schema["type"]}"
puts "   - required: #{json_schema["required"]}"
puts "   - properties: #{json_schema["properties"].keys}"
puts "   - name.maxLength: #{json_schema["properties"]["name"]["maxLength"]}"

puts "\n8. Serialization"
puts "-" * 40
SerializeSchema = Validrb.schema do
  field :name, :string
  field :created_at, :date
  field :amount, :decimal
  field :tags, :array, of: :string
end

result = SerializeSchema.safe_parse({
  name: "Test Item",
  created_at: "2024-01-15",
  amount: "99.99",
  tags: [:ruby, :validation]
})

puts "   Parsed data:"
puts "   #{result.data}"

puts "\n   Serialized to hash:"
serialized = result.dump
puts "   #{serialized}"

puts "\n   Serialized to JSON:"
puts "   #{result.to_json}"

puts "\n9. Complete Phase 4 Example: API Request"
puts "-" * 40
# Define a slug type
Validrb.define_type(:slug) do
  coerce { |v| v.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "") }
  validate { |v| v.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) }
end

CreatePostSchema = Validrb.schema do
  field :title, :string, min: 1, max: 200
  field :slug, :slug
  field :content, :string, min: 10
  field :status, :string, literal: %w[draft published]
  field :author_id, :integer,
        refine: ->(id, ctx) { ctx.nil? || !ctx.key?(:allowed_authors) || ctx[:allowed_authors].include?(id) }
  field :tags, :array, of: :string, default: []
  field :published_at, :datetime,
        when: ->(data) { data[:status] == "published" }
end

ctx = Validrb.context(allowed_authors: [1, 2, 3])

result = CreatePostSchema.safe_parse({
  title: "Hello World!",
  slug: "Hello World Post",
  content: "This is my first blog post with enough content.",
  status: "published",
  author_id: 1,
  tags: ["ruby", "tutorial"],
  published_at: "2024-01-15T10:00:00Z"
}, context: ctx)

puts "   Create post request:"
puts "   Success: #{result.success?}"
if result.success?
  puts "   Slug: #{result.data[:slug]} (auto-slugified)"
  puts "   Status: #{result.data[:status]}"
  puts "   JSON: #{result.to_json[0..100]}..."
end

# Clean up
Validrb::Types.registry.delete(:slug)

puts "\n" + "=" * 60
puts "  DEMO COMPLETE"
puts "=" * 60
