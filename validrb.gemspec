# frozen_string_literal: true

require_relative 'lib/validrb/version'

Gem::Specification.new do |spec|
  spec.name = 'validrb'
  spec.version = Validrb::VERSION
  spec.authors = ['Elysium Arc']
  spec.email = ['imam6mouad@gmail.com']

  spec.summary = 'A Ruby schema validation library with type coercion'
  spec.description = <<~DESC
    Validrb is a powerful Ruby schema validation library inspired by Pydantic and Zod.
    It provides type coercion, rich constraints, schema composition, union types,
    discriminated unions, custom validators, JSON Schema generation, and serialization.
  DESC
  spec.homepage = 'http://github.com/Elysium-Arc/Validrb'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'documentation_uri' => spec.homepage,
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        f == 'demo.rb'
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # bigdecimal is used for Decimal type - required explicitly for Ruby 3.4+
  spec.add_dependency 'bigdecimal'
end
