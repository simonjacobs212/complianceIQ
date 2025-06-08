require_relative "boot"
require "dotenv/load"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ComplianceiqBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.autoload_lib(ignore: %w[assets tasks])

    if ENV["SERVICE_ACCOUNT_JSON_BASE64"]
     decoded = Base64.decode64(ENV["SERVICE_ACCOUNT_JSON_BASE64"])
     File.write(Rails.root.join("config", "service_account.json"), decoded)
    end


    config.api_only = true
  end
end
