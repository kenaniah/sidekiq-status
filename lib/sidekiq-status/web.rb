# adapted from https://github.com/cryo28/sidekiq_status
require_relative 'helpers'

module Sidekiq::Status
  # Hook into *Sidekiq::Web* Sinatra app which adds a new "/statuses" page
  module Web
    # Location of Sidekiq::Status::Web view templates
    VIEW_PATH = File.expand_path('../../../web/views', __FILE__)

    DEFAULT_PER_PAGE_OPTS = [25, 50, 100].freeze
    DEFAULT_PER_PAGE = 25

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

      # Allow method overrides to support RESTful deletes
      app.set :method_override, true

      app.helpers Helpers

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

        sort_by = has_sort_by?(params[:sort_by]) ? params[:sort_by] : "updated_at"
        sort_dir = "asc"

        if params[:sort_dir] == "asc"
          @statuses = @statuses.sort { |x,y| (x[sort_by] <=> y[sort_by]) || -1 }
        else
          sort_dir = "desc"
          @statuses = @statuses.sort { |y,x| (x[sort_by] <=> y[sort_by]) || 1 }
        end

        if params[:status] && params[:status] != "all"
          @statuses = @statuses.select {|job_status| job_status["status"] == params[:status] }
        end

        # Sidekiq pagination
        @total_size = @statuses.count
        @count = params[:per_page] ? params[:per_page].to_i : Sidekiq::Status::Web.default_per_page
        @count = @total_size if params[:per_page] == 'all'
        @current_page = params[:page].to_i < 1 ? 1 : params[:page].to_i
        @statuses = @statuses.slice((@current_page - 1) * @count, @count)

        @headers = [
          {id: "worker", name: "Worker / JID", class: nil, url: nil},
          {id: "args", name: "Arguments", class: nil, url: nil},
          {id: "status", name: "Status", class: nil, url: nil},
          {id: "updated_at", name: "Last Updated", class: nil, url: nil},
          {id: "pct_complete", name: "Progress", class: nil, url: nil},
          {id: "elapsed", name: "Time Elapsed", class: nil, url: nil},
          {id: "eta", name: "ETA", class: nil, url: nil},
        ]

        @headers.each do |h|
          h[:url] = "statuses?" + params.merge("sort_by" => h[:id], "sort_dir" => (sort_by == h[:id] && sort_dir == "asc") ? "desc" : "asc").map{|k, v| "#{k}=#{CGI.escape v.to_s}"}.join("&")
          h[:class] = "sorted_#{sort_dir}" if sort_by == h[:id]
        end

        erb(sidekiq_status_template(:statuses))
      end

      app.get '/statuses/:jid' do
        job = Sidekiq::Status::get_all params['jid']

        if job.empty?
          throw :halt, [404, {"Content-Type" => "text/html"}, [erb(sidekiq_status_template(:status_not_found))]]
        else
          @status = add_details_to_status(job)
          erb(sidekiq_status_template(:status))
        end
      end

      # Handles POST requests with method override for statuses
      app.post '/statuses' do
        case params[:_method]
        when 'put'
          # Retries a failed job from the status list
          retry_job_action
        when 'delete'
          # Removes a completed job from the status list
          delete_job_action
        else
          throw :halt, [405, {"Content-Type" => "text/html"}, ["Method not allowed"]]
        end
      end

      # Retries a failed job from the status list
      app.put '/statuses' do
        retry_job_action
      end

      # Removes a completed job from the status list
      app.delete '/statuses' do
        delete_job_action
      end
    end
  end
end

unless defined?(Sidekiq::Web)
  require 'delegate' # Needed for sidekiq 5.x
  require 'sidekiq/web'
end

Sidekiq::Web.register(Sidekiq::Status::Web)
["per_page", "sort_by", "sort_dir", "status"].each do |key|
  Sidekiq::WebHelpers::SAFE_QPARAMS.push(key)
end
Sidekiq::Web.tabs["Statuses"] = "statuses"

# Register custom JavaScript and CSS assets
ASSETS_PATH = File.expand_path('../../../web', __FILE__)

Sidekiq::Web.use Rack::Static,
  urls: ['/assets'],
  root: ASSETS_PATH,
  cascade: true,
  header_rules: [[:all, { 'cache-control' => 'private, max-age=86400' }]]
