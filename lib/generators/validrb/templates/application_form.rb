# frozen_string_literal: true

# Base class for all form objects in this application.
#
# @example Usage
#   class UserForm < ApplicationForm
#     schema do
#       field :name, :string, min: 2, max: 100
#       field :email, :string, format: :email
#       field :age, :integer, min: 0, optional: true
#     end
#   end
#
#   # In controller:
#   form = UserForm.new(params[:user])
#   if form.valid?
#     User.create!(form.attributes)
#   end
#
#   # In views (works with form_with):
#   <%= form_with model: @user_form do |f| %>
#     <%= f.text_field :name %>
#     <%= f.email_field :email %>
#   <% end %>
#
class ApplicationForm < Validrb::Rails::FormObject
  # Add shared form functionality here

  # Example: Add a class method to build from ActiveRecord
  # def self.from_record(record)
  #   new(record.attributes.symbolize_keys)
  # end

  # Example: Add error summary helper
  # def error_summary
  #   errors.full_messages.join(", ")
  # end
end
