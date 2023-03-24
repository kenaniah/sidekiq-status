require "sidekiq-status/job"

module Sidekiq::Status
  Worker = Job
end
