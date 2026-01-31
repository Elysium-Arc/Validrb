# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Required for Ruby 3.4+ (no longer in default gems)
gem "bigdecimal"

group :development, :test do
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.12"
  gem "rspec_junit_formatter", "~> 0.6"
  gem "rubocop", "~> 1.50"
  gem "rubocop-rspec", "~> 2.20"

  # For Rails integration tests
  gem "activemodel", "~> 7.0"
  gem "activesupport", "~> 7.0"
end

group :benchmark do
  gem "benchmark-ips", "~> 2.12"
  gem "memory_profiler", "~> 1.0"
  gem "dry-validation", "~> 1.10"
  gem "dry-schema", "~> 1.13"
end
