# frozen_string_literal: true

require "validrb"

# Check for Rails/ActiveModel
begin
  require "active_model"
  require "active_support/concern"
rescue LoadError
  raise LoadError, "Validrb::Rails requires Rails or ActiveModel. Add 'rails' or 'activemodel' to your Gemfile."
end

require_relative "rails/error_converter"
require_relative "rails/form_object"
require_relative "rails/controller"
require_relative "rails/model"

module Validrb
  # Rails integration for Validrb
  #
  # @example Setup in Rails application
  #   # config/initializers/validrb.rb
  #   require "validrb/rails"
  #
  #   # Include controller helpers globally (optional)
  #   ActiveSupport.on_load(:action_controller) do
  #     include Validrb::Rails::Controller
  #   end
  #
  # @example Using FormObject
  #   class UserForm < Validrb::Rails::FormObject
  #     schema do
  #       field :name, :string, min: 2
  #       field :email, :string, format: :email
  #     end
  #   end
  #
  # @example Using Controller helpers
  #   class UsersController < ApplicationController
  #     include Validrb::Rails::Controller
  #
  #     def create
  #       result = validate_params(UserSchema, :user)
  #       # ...
  #     end
  #   end
  #
  # @example Using Model validation
  #   class User < ApplicationRecord
  #     include Validrb::Rails::Model
  #
  #     validates_with_schema do
  #       field :name, :string, min: 2
  #       field :email, :string, format: :email
  #     end
  #   end
  #
  module Rails
    class << self
      # Install Validrb::Rails into a Rails application
      # Call this from an initializer
      def install!
        # Include controller helpers in all controllers
        if defined?(ActionController::Base)
          ActionController::Base.include(Controller)
        end

        if defined?(ActionController::API)
          ActionController::API.include(Controller)
        end
      end
    end
  end

  # Railtie for automatic Rails integration
  if defined?(::Rails::Railtie)
    class Railtie < ::Rails::Railtie
      initializer "validrb.configure" do
        # Auto-configuration can be added here
      end

      # Add Validrb::Rails::Controller to ActionController
      initializer "validrb.controller" do
        ActiveSupport.on_load(:action_controller_base) do
          include Validrb::Rails::Controller
        end

        ActiveSupport.on_load(:action_controller_api) do
          include Validrb::Rails::Controller
        end
      end
    end
  end
end
