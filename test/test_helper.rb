ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase

    # Include ActiveJob test helpers for testing enqueued jobs
    include ActiveJob::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Configure Active Storage URL options for tests
    setup do
      ActiveStorage::Current.url_options = { host: "test.host" }
    end

  end
end

module InertiaTestHelpers

  def inertia_props
    return @inertia_props if @inertia_props

    if @response.media_type == "application/json"
      # JSON response (when X-Inertia header is present)
      @inertia_props = JSON.parse(@response.body)
    else
      # HTML response - extract from data-page attribute
      doc = Nokogiri::HTML(@response.body)
      data_page = doc.at_css("#app")&.attr("data-page")
      @inertia_props = data_page ? JSON.parse(data_page) : {}
    end
  end

  def inertia_component
    inertia_props["component"]
  end

  def inertia_shared_props
    inertia_props["props"] || {}
  end

end

class ActionDispatch::IntegrationTest

  include InertiaTestHelpers

  # Authentication helper for tests
  def sign_in(user)
    post "/login", params: {
      email_address: user.email_address,
      password: "password123"  # Fixture users use this password
    }
  end

end

require "support/vcr_setup"
