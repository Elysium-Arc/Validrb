# frozen_string_literal: true

require "json"

module Validrb
  # Serializer for converting validated data back to primitives
  # Useful for JSON serialization, database storage, etc.
  class Serializer
    # Serialize a value to a primitive representation
    def self.dump(value, format: :hash)
      serialized = serialize_value(value)

      case format
      when :hash
        serialized
      when :json
        JSON.generate(serialized)
      else
        raise ArgumentError, "Unknown format: #{format}"
      end
    end

    # Serialize a value recursively
    def self.serialize_value(value)
      case value
      when nil, true, false, ::Integer, ::Float, ::String
        value
      when ::Symbol
        value.to_s
      when ::BigDecimal
        value.to_s("F")
      when ::Date
        value.iso8601
      when ::DateTime
        value.iso8601
      when ::Time
        value.iso8601
      when ::Array
        value.map { |v| serialize_value(v) }
      when ::Hash
        value.transform_keys(&:to_s).transform_values { |v| serialize_value(v) }
      else
        # Try to_h, to_s as fallbacks
        if value.respond_to?(:to_h)
          serialize_value(value.to_h)
        else
          value.to_s
        end
      end
    end
  end

  # Add serialization to Result
  class Success
    def dump(format: :hash)
      Serializer.dump(@data, format: format)
    end

    def to_json(*args)
      dump(format: :json)
    end
  end

  class Failure
    def dump(format: :hash)
      serialized_errors = @errors.map do |e|
        {
          "path" => e.path.map(&:to_s),
          "message" => e.message,
          "code" => e.code.to_s
        }
      end

      case format
      when :hash
        { "errors" => serialized_errors }
      when :json
        JSON.generate({ "errors" => serialized_errors })
      else
        raise ArgumentError, "Unknown format: #{format}"
      end
    end

    def to_json(*args)
      dump(format: :json)
    end
  end

  # Add serialization to Schema
  class Schema
    # Serialize validated data
    def dump(data, format: :hash)
      result = safe_parse(data)

      if result.success?
        result.dump(format: format)
      else
        raise ValidationError, result.errors
      end
    end

    # Parse and serialize in one step (returns Result with serialized data)
    def safe_dump(data, format: :hash)
      result = safe_parse(data)

      if result.success?
        Success.new(Serializer.dump(result.data, format: :hash))
      else
        result
      end
    end
  end
end
