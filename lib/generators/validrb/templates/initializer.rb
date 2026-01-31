# frozen_string_literal: true

# Validrb Configuration
# See: https://github.com/your-repo/validrb

require "validrb/rails"

# Configure I18n (optional)
# Validrb::I18n.locale = :en
# Validrb::I18n.add_translations(:en,
#   required: "is required",
#   invalid_type: "must be a %{expected}"
# )

# Configure default API error format (optional)
# Validrb::Rails::ApiErrorResponse.validrb_error_format = :jsonapi

# The Railtie automatically includes Validrb::Rails::Controller
# in ActionController::Base and ActionController::API.
#
# If you want to include additional modules globally:
#
# Rails.application.config.to_prepare do
#   ActionController::API.include Validrb::Rails::ApiErrorHandler
# end
