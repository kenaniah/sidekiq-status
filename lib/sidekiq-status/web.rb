# adapted from https://github.com/cryo28/sidekiq_status
require_relative 'helpers'

module Sidekiq::Status
  # Hook into *Sidekiq::Web* Sinatra app which adds a new "/statuses" page
  module Web
    # Location of Sidekiq::Status::Web view templates
    ROOT = File.expand_path("../../web", File.dirname(__FILE__))
    VIEWS = File.expand_path("views", ROOT)

    DEFAULT_PER_PAGE_OPTS = [25, 50, 100].freeze
    DEFAULT_PER_PAGE = 25
    COMMON_STATUS_HASH_KEYS = %w(update_time jid status worker args label pct_complete total at message working_at elapsed eta)

    class << self
      def per_page_opts= arr
        @per_page_opts = arr
      end
      def per_page_opts
        @per_page_opts || DEFAULT_PER_PAGE_OPTS
      end
      def default_per_page= val
        @default_per_page = val
      end
      def default_per_page
        @default_per_page || DEFAULT_PER_PAGE
      end
    end

    # @param [Sidekiq::Web] app
    def self.registered(app)
      app.helpers Web::Helpers

      app.get '/statuses' do
        jids = Sidekiq::Status.redis_adapter do |conn|
          conn.scan(match: 'sidekiq:status:*', count: 100).map do |key|
            key.split(':').last
          end.uniq
        end
        @statuses = []

        jids.each do |jid|
          status = Sidekiq::Status::get_all jid
          next if !status || status.count < 2
          status = add_details_to_status(status)
          @statuses << status
        end

        sort_by = has_sort_by?(safe_url_params("sort_by")) ? safe_url_params("sort_by") : "update_time"
        sort_dir = "asc"

        if safe_url_params("sort_dir") == "asc"
          @statuses = @statuses.sort { |x,y| (x[sort_by] <=> y[sort_by]) || -1 }
        else
          sort_dir = "desc"
          @statuses = @statuses.sort { |y,x| (x[sort_by] <=> y[sort_by]) || 1 }
        end

        if safe_url_params("status") && safe_url_params("status") != "all"
          @statuses = @statuses.select {|job_status| job_status["status"] == safe_url_params("status") }
        end

        # Sidekiq pagination
        @total_size = @statuses.count
        @count = safe_url_params("per_page") ? safe_url_params("per_page").to_i : Sidekiq::Status::Web.default_per_page
        @count = @total_size if safe_url_params("per_page") == 'all'
        @current_page = safe_url_params("page").to_i < 1 ? 1 : safe_url_params("page").to_i
        @statuses = @statuses.slice((@current_page - 1) * @count, @count)

        @headers = [
          {id: "worker", name: "Worker / JID", class: nil, url: nil},
          {id: "args", name: "Arguments", class: nil, url: nil},
          {id: "status", name: "Status", class: nil, url: nil},
          {id: "update_time", name: "Last Updated", class: nil, url: nil},
          {id: "pct_complete", name: "Progress", class: nil, url: nil},
          {id: "elapsed", name: "Time Elapsed", class: nil, url: nil},
          {id: "eta", name: "ETA", class: nil, url: nil},
        ]

        @headers.each do |h|
          h[:url] = "statuses?" + qparams(
            "sort_by" => h[:id],
            "sort_dir" => (sort_by == h[:id] && sort_dir == "asc") ? "desc" : "asc"
          )
          h[:class] = "sorted_#{sort_dir}" if sort_by == h[:id]
        end

        erb(:statuses, views: VIEWS)
      end

      app.get '/statuses/:jid' do
        job = Sidekiq::Status::get_all safe_route_params(:jid)

        if job.empty?
          throw :halt, [404, {"Content-Type" => "text/html"}, [erb(:status_not_found, views: VIEWS)]]
        else
          @status = add_details_to_status(job)

          erb(:status, views: VIEWS)
        end
      end

      # Retries a failed job from the status list
      app.put '/statuses' do
        job = Sidekiq::RetrySet.new.find_job(safe_url_params("jid"))
        job ||= Sidekiq::DeadSet.new.find_job(safe_url_params("jid"))
        job.retry if job
        throw :halt, [302, { "Location" => request.referer }, []]
      end

      # Removes a completed job from the status list
      app.delete '/statuses' do
        Sidekiq::Status.delete(safe_url_params("jid"))
        throw :halt, [302, { "Location" => request.referer }, []]
      end
    end
  end
end

unless defined?(Sidekiq::Web)
  require 'delegate'
  require 'sidekiq/web'
end

if Sidekiq.major_version > 6
  Sidekiq::Web.configure do |config|
    if Sidekiq.major_version >= 8
      config.register_extension(
        Sidekiq::Status::Web,
        name: "statuses",
        tab: ["Statuses"],
        index: ["statuses"],
        root_dir: Sidekiq::Status::Web::ROOT,
        asset_paths: ["images", "javascripts", "stylesheets"]
      )
    else
      config.register(Sidekiq::Status::Web, name: "statuses", tab: ["Statuses"], index: "statuses")
    end
  end
else
  Sidekiq::Web.register(Sidekiq::Status::Web)
  if Sidekiq::Web.tabs.is_a?(Array)
    Sidekiq::Web.tabs << "statuses"
  else
    Sidekiq::Web.tabs["Statuses"] = "statuses"
  end
end

["per_page", "sort_by", "sort_dir", "status"].each do |key|
  Sidekiq::WebHelpers::SAFE_QPARAMS.push(key)
end
