# frozen_string_literal: true

module Validrb
  # Validation context - carries additional data through the validation pipeline
  # Useful for passing request context, current user, locale, etc.
  class Context
    attr_reader :data

    def initialize(**data)
      @data = data.freeze
      freeze
    end

    def [](key)
      @data[key.to_sym]
    end

    def key?(key)
      @data.key?(key.to_sym)
    end

    def fetch(key, *args, &block)
      @data.fetch(key.to_sym, *args, &block)
    end

    def to_h
      @data.dup
    end

    # Empty context singleton
    EMPTY = new.freeze

    def self.empty
      EMPTY
    end

    def empty?
      @data.empty?
    end
  end
end
