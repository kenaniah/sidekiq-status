# This file is used to load the test environment for Sidekiq::Status when launching Sidekiq workers directly
require "sidekiq-status"
require_relative "support/test_jobs"

Sidekiq.configure_client do |config|
  Sidekiq::Status.configure_client_middleware config
end

Sidekiq.configure_server do |config|
  Sidekiq::Status.configure_server_middleware config
  Sidekiq::Status.configure_client_middleware config
end
