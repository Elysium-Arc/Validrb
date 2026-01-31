# frozen_string_literal: true

require "spec_helper"
require "validrb/rails"

RSpec.describe "Rails Security" do
  describe "Mass Assignment Protection" do
    let(:form_class) do
      Class.new(Validrb::Rails::FormObject) do
        def self.name
          "SecureForm"
        end

        schema do
          field :name, :string
          field :email, :string
        end
      end
    end

    it "ignores attributes not in schema" do
      form = form_class.new(
        name: "John",
        email: "john@example.com",
        admin: true,
        role: "superuser",
        password_digest: "hacked"
      )

      expect(form).not_to respond_to(:admin)
      expect(form).not_to respond_to(:role)
      expect(form).not_to respond_to(:password_digest)
    end

    it "only includes schema fields in attributes" do
      form = form_class.new(
        name: "John",
        email: "john@example.com",
        admin: true
      )
      form.valid?

      expect(form.attributes.keys).to contain_exactly(:name, :email)
      expect(form.attributes).not_to have_key(:admin)
    end
  end

  describe "Input Sanitization" do
    describe "String fields" do
      let(:schema) do
        Validrb.schema do
          field :name, :string, max: 100
          field :bio, :string, max: 500
        end
      end

      it "handles extremely long strings" do
        long_string = "a" * 10_000
        result = schema.safe_parse(name: long_string, bio: "test")

        expect(result).to be_failure
        expect(result.errors.first.path).to eq([:name])
      end

      it "handles null bytes in strings" do
        result = schema.safe_parse(name: "John\x00Doe", bio: "test")

        # Should coerce successfully (null bytes are valid in Ruby strings)
        expect(result).to be_success
        expect(result.data[:name]).to eq("John\x00Doe")
      end

      it "handles unicode strings" do
        result = schema.safe_parse(name: "日本語テスト", bio: "émoji 🎉")

        expect(result).to be_success
        expect(result.data[:name]).to eq("日本語テスト")
        expect(result.data[:bio]).to eq("émoji 🎉")
      end

      it "handles mixed encoding strings" do
        result = schema.safe_parse(name: "Héllo Wörld", bio: "test")

        expect(result).to be_success
      end
    end

    describe "Integer fields" do
      let(:schema) do
        Validrb.schema do
          field :count, :integer
          field :amount, :integer, min: 0, max: 1_000_000
        end
      end

      it "handles integer overflow attempts" do
        huge_number = "999999999999999999999999999999"
        result = schema.safe_parse(count: huge_number, amount: 100)

        # Ruby handles big integers, so this should work
        expect(result).to be_success
        expect(result.data[:count]).to eq(999999999999999999999999999999)
      end

      it "rejects non-numeric strings" do
        result = schema.safe_parse(count: "not_a_number", amount: 100)

        expect(result).to be_failure
      end

      it "handles negative numbers correctly" do
        result = schema.safe_parse(count: -5, amount: -100)

        expect(result).to be_failure
        expect(result.errors.first.path).to eq([:amount])
      end

      it "handles float to integer coercion" do
        result = schema.safe_parse(count: 5.9, amount: 100)

        # Should fail because 5.9 is not a whole number
        expect(result).to be_failure
      end

      it "handles string float to integer" do
        result = schema.safe_parse(count: "5.0", amount: 100)

        # "5.0" can be coerced to integer 5 (valid whole number representation)
        expect(result).to be_success
        expect(result.data[:count]).to eq(5)
      end
    end

    describe "Boolean fields" do
      let(:schema) do
        Validrb.schema do
          field :active, :boolean
          field :verified, :boolean
        end
      end

      it "handles truthy string variations" do
        %w[true TRUE True yes YES Yes 1 on ON].each do |val|
          result = schema.safe_parse(active: val, verified: true)
          expect(result).to be_success, "Expected '#{val}' to coerce to true"
          expect(result.data[:active]).to be true
        end
      end

      it "handles falsy string variations" do
        %w[false FALSE False no NO No 0 off OFF].each do |val|
          result = schema.safe_parse(active: val, verified: true)
          expect(result).to be_success, "Expected '#{val}' to coerce to false"
          expect(result.data[:active]).to be false
        end
      end

      it "rejects invalid boolean strings" do
        result = schema.safe_parse(active: "maybe", verified: true)

        expect(result).to be_failure
      end
    end
  end

  describe "Path Traversal Prevention" do
    let(:schema) do
      Validrb.schema do
        field :filename, :string, format: /\A[\w\-\.]+\z/
      end
    end

    it "rejects path traversal attempts" do
      dangerous_inputs = [
        "../../../etc/passwd",
        "..\\..\\windows\\system32",
        "file/../../../secret",
        "/etc/passwd",
        "C:\\Windows\\System32"
      ]

      dangerous_inputs.each do |input|
        result = schema.safe_parse(filename: input)
        expect(result).to be_failure, "Expected '#{input}' to be rejected"
      end
    end

    it "accepts safe filenames" do
      safe_inputs = %w[document.pdf image.png file-name_123.txt]

      safe_inputs.each do |input|
        result = schema.safe_parse(filename: input)
        expect(result).to be_success, "Expected '#{input}' to be accepted"
      end
    end
  end

  describe "SQL Injection Prevention" do
    # Note: Validrb doesn't directly prevent SQL injection (that's the ORM's job),
    # but we can test that it properly validates and doesn't execute anything

    let(:schema) do
      Validrb.schema do
        field :search, :string, max: 100
        field :id, :integer
      end
    end

    it "treats SQL injection attempts as plain strings" do
      malicious_inputs = [
        "'; DROP TABLE users; --",
        "1 OR 1=1",
        "admin'--",
        "1; DELETE FROM users"
      ]

      malicious_inputs.each do |input|
        result = schema.safe_parse(search: input, id: 1)
        # String fields accept these as valid strings
        expect(result).to be_success
        # But the data is just a string, not executed
        expect(result.data[:search]).to eq(input)
      end
    end

    it "rejects SQL injection in integer fields" do
      result = schema.safe_parse(search: "test", id: "1 OR 1=1")

      expect(result).to be_failure
    end
  end

  describe "XSS Prevention" do
    # Note: Validrb doesn't escape HTML (that's the view's job),
    # but we can test format constraints

    let(:schema) do
      Validrb.schema do
        field :name, :string, format: /\A[\w\s\-\.]+\z/
        field :comment, :string  # No format restriction
      end
    end

    it "rejects HTML in restricted fields" do
      xss_attempts = [
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert('xss')>",
        "javascript:alert('xss')"
      ]

      xss_attempts.each do |input|
        result = schema.safe_parse(name: input, comment: "safe")
        expect(result).to be_failure, "Expected '#{input}' to be rejected in name field"
      end
    end

    it "allows HTML in unrestricted fields (view should escape)" do
      result = schema.safe_parse(name: "John Doe", comment: "<script>alert('xss')</script>")

      expect(result).to be_success
      expect(result.data[:comment]).to eq("<script>alert('xss')</script>")
    end
  end

  describe "Email Validation Security" do
    let(:schema) do
      Validrb.schema do
        field :email, :string, format: :email
      end
    end

    it "rejects malformed emails" do
      invalid_emails = [
        "notanemail",
        "@nodomain.com",
        "no@domain",
        "spaces in@email.com",
        "multiple@@at.com"
      ]

      invalid_emails.each do |email|
        result = schema.safe_parse(email: email)
        expect(result).to be_failure, "Expected '#{email}' to be rejected"
      end
    end

    it "accepts valid emails" do
      valid_emails = [
        "simple@example.com",
        "user.name@example.com",
        "user+tag@example.com",
        "user@subdomain.example.com"
      ]

      valid_emails.each do |email|
        result = schema.safe_parse(email: email)
        expect(result).to be_success, "Expected '#{email}' to be accepted"
      end
    end
  end

  describe "URL Validation Security" do
    let(:schema) do
      Validrb.schema do
        field :website, :string, format: :url
      end
    end

    it "rejects dangerous URL schemes" do
      dangerous_urls = [
        "javascript:alert('xss')",
        "data:text/html,<script>alert('xss')</script>",
        "file:///etc/passwd"
      ]

      dangerous_urls.each do |url|
        result = schema.safe_parse(website: url)
        expect(result).to be_failure, "Expected '#{url}' to be rejected"
      end
    end

    it "accepts safe URLs" do
      safe_urls = [
        "https://example.com",
        "http://example.com/path",
        "https://subdomain.example.com/path?query=value"
      ]

      safe_urls.each do |url|
        result = schema.safe_parse(website: url)
        expect(result).to be_success, "Expected '#{url}' to be accepted"
      end
    end
  end

  describe "Denial of Service Prevention" do
    describe "ReDoS (Regular Expression DoS)" do
      # Validrb's built-in formats should be safe from ReDoS
      let(:schema) do
        Validrb.schema do
          field :email, :string, format: :email
          field :url, :string, format: :url
          field :uuid, :string, format: :uuid
        end
      end

      it "handles long inputs without hanging" do
        long_input = "a" * 10_000

        # This should complete quickly, not hang
        start_time = Time.now
        schema.safe_parse(email: long_input, url: long_input, uuid: long_input)
        elapsed = Time.now - start_time

        expect(elapsed).to be < 1.0  # Should complete in under 1 second
      end
    end

    describe "Deep nesting protection" do
      it "handles deeply nested objects" do
        # Create a deeply nested schema
        inner = Validrb.schema { field :value, :string }

        current = inner
        10.times do
          outer_schema = current
          current = Validrb.schema do
            field :nested, :object, schema: outer_schema
          end
        end

        # Create deeply nested data
        data = { value: "test" }
        10.times { data = { nested: data } }

        result = current.safe_parse(data)
        expect(result).to be_success
      end
    end

    describe "Large array protection" do
      let(:schema) do
        Validrb.schema do
          field :items, :array, of: :string, max: 100
        end
      end

      it "rejects arrays exceeding max length" do
        large_array = Array.new(1000) { "item" }
        result = schema.safe_parse(items: large_array)

        expect(result).to be_failure
      end

      it "accepts arrays within limit" do
        valid_array = Array.new(50) { "item" }
        result = schema.safe_parse(items: valid_array)

        expect(result).to be_success
      end
    end
  end
end
