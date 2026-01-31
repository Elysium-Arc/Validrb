# frozen_string_literal: true

require "rails/generators/base"

module Validrb
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install Validrb Rails integration"

      def create_initializer
        template "initializer.rb", "config/initializers/validrb.rb"
      end

      def create_application_form
        template "application_form.rb", "app/forms/application_form.rb"
      end

      def create_forms_directory
        empty_directory "app/forms"
      end

      def create_schemas_directory
        empty_directory "app/schemas"
      end

      def add_autoload_paths
        application_rb = "config/application.rb"
        return unless File.exist?(application_rb)

        inject_into_file application_rb, after: "class Application < Rails::Application\n" do
          <<-RUBY
    # Autoload Validrb forms and schemas
    config.autoload_paths += %W[\#{config.root}/app/forms]
    config.autoload_paths += %W[\#{config.root}/app/schemas]

          RUBY
        end
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
