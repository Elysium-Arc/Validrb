# frozen_string_literal: true

require_relative "lib/validrb/version"

Gem::Specification.new do |spec|
  spec.name = "validrb"
  spec.version = Validrb::VERSION
  spec.authors = ["Validrb Contributors"]
  spec.email = ["validrb@example.com"]

  spec.summary = "A Ruby schema validation library with type coercion"
  spec.description = "Validrb is a Ruby schema validation library inspired by Pydantic/Zod, " \
                     "providing type coercion, constraint validation, and a clean DSL for " \
                     "defining data schemas."
  spec.homepage = "https://github.com/validrb/validrb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Zero runtime dependencies
end
