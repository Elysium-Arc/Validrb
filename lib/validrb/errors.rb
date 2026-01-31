# frozen_string_literal: true

module Validrb
  # Represents a single validation error with path tracking
  class Error
    attr_reader :path, :message, :code

    def initialize(path:, message:, code: nil)
      @path = Array(path).freeze
      @message = message.freeze
      @code = code&.to_sym
      freeze
    end

    def full_path
      return "" if path.empty?

      path.map(&:to_s).join(".")
    end

    def to_s
      prefix = full_path.empty? ? "" : "#{full_path}: "
      "#{prefix}#{message}"
    end

    def to_h
      { path: path, message: message, code: code }.compact
    end

    def ==(other)
      other.is_a?(Error) &&
        path == other.path &&
        message == other.message &&
        code == other.code
    end
    alias eql? ==

    def hash
      [path, message, code].hash
    end
  end

  # Collection of validation errors with utility methods
  class ErrorCollection
    include Enumerable

    def initialize(errors = [])
      @errors = errors.dup.freeze
      freeze
    end

    def each(&block)
      @errors.each(&block)
    end

    def [](index)
      @errors[index]
    end

    def size
      @errors.size
    end
    alias length size
    alias count size

    def empty?
      @errors.empty?
    end

    def any?
      @errors.any?
    end

    def add(error)
      ErrorCollection.new(@errors + [error])
    end

    def merge(other)
      ErrorCollection.new(@errors + other.to_a)
    end

    def for_path(*path)
      path = path.flatten
      ErrorCollection.new(@errors.select { |e| e.path[0...path.size] == path })
    end

    def messages
      @errors.map(&:message)
    end

    def full_messages
      @errors.map(&:to_s)
    end

    def to_a
      @errors.dup
    end

    def to_h
      @errors.group_by(&:full_path).transform_values { |errs| errs.map(&:message) }
    end
  end

  # Exception raised when parse() fails validation
  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors.is_a?(ErrorCollection) ? errors : ErrorCollection.new(Array(errors))
      super(build_message)
    end

    private

    def build_message
      msgs = @errors.full_messages
      return "Validation failed" if msgs.empty?

      "Validation failed: #{msgs.join("; ")}"
    end
  end
end
