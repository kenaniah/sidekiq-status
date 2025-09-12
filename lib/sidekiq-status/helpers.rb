module Sidekiq::Status
  module Web
    module Helpers
      COMMON_STATUS_HASH_KEYS = %w(update_time jid status worker args label pct_complete total at message working_at elapsed eta)

      def safe_url_params(key)
        return url_params(key) if Sidekiq.major_version >= 8

        warn { "URL parameter `#{key}` should be accessed via String, not Symbol (at #{caller(3..3).first})" } if key.is_a?(Symbol)
        request.params[key.to_s]
      end

      def safe_route_params(key)
        return route_params(key) if Sidekiq.major_version >= 8

        warn { "Route parameter `#{key}` should be accessed via Symbol, not String (at #{caller(3..3).first})" } if key.is_a?(String)
        env["rack.route_params"][key.to_sym]
      end

      def csrf_tag
        "<input type='hidden' name='authenticity_token' value='#{session[:csrf]}'/>"
      end

      def poll_path
        "?#{request.query_string}" if safe_url_params("poll")
      end

      def add_details_to_status(status)
        status['label'] = status_label(status['status'])
        status["pct_complete"] ||= pct_complete(status)
        status["elapsed"] ||= elapsed(status).to_s
        status["eta"] ||= eta(status).to_s
        status["custom"] = process_custom_data(status)
        return status
      end

      def process_custom_data(hash)
        hash.reject { |key, _| COMMON_STATUS_HASH_KEYS.include?(key) }
      end

      def pct_complete(status)
        return 100 if status['status'] == 'complete'
        Sidekiq::Status::pct_complete(status['jid']) || 0
      end

      def elapsed(status)
        case status['status']
        when 'complete'
          Sidekiq::Status.update_time(status['jid']) - Sidekiq::Status.working_at(status['jid'])
        when 'working', 'retrying'
          Time.now.to_i - Sidekiq::Status.working_at(status['jid'])
        end
      end

      def eta(status)
        Sidekiq::Status.eta(status['jid']) if status['status'] == 'working'
      end

      def status_label(status)
        case status
        when 'complete'
          'success'
        when 'working', 'retrying'
          'warning'
        when 'queued'
          'info'
        else
          'danger'
        end
      end

      def has_sort_by?(value)
        ["worker", "status", "update_time", "pct_complete", "message", "args"].include?(value)
      end
    end
  end
end
