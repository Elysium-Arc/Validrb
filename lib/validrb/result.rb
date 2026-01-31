# frozen_string_literal: true

module Validrb
  # Represents a successful validation result
  class Success
    attr_reader :data

    def initialize(data)
      @data = data.freeze
      freeze
    end

    def success?
      true
    end

    def failure?
      false
    end

    def errors
      ErrorCollection.new
    end

    def value_or(_default = nil)
      @data
    end

    def map
      Success.new(yield(@data))
    end

    def flat_map
      yield(@data)
    end

    def ==(other)
      other.is_a?(Success) && data == other.data
    end
    alias eql? ==

    def hash
      [self.class, data].hash
    end
  end

  # Represents a failed validation result
  class Failure
    attr_reader :errors

    def initialize(errors)
      @errors = errors.is_a?(ErrorCollection) ? errors : ErrorCollection.new(Array(errors))
      freeze
    end

    def success?
      false
    end

    def failure?
      true
    end

    def data
      nil
    end

    def value_or(default = nil)
      block_given? ? yield(@errors) : default
    end

    def map
      self
    end

    def flat_map
      self
    end

    def ==(other)
      other.is_a?(Failure) && errors.to_a == other.errors.to_a
    end
    alias eql? ==

    def hash
      [self.class, errors.to_a].hash
    end
  end
end
