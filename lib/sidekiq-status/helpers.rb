module Sidekiq::Status
  module Web
    module Helpers
      COMMON_STATUS_HASH_KEYS = %w(enqueued_at started_at updated_at ended_at jid status worker args label pct_complete total at message elapsed eta)

      def safe_url_params(key)
        return url_params(key) if Sidekiq.major_version >= 8
        request.params[key.to_s]
      end

      def safe_route_params(key)
        return route_params(key) if Sidekiq.major_version >= 8
        env["rack.route_params"][key.to_sym]
      end

      def csrf_tag
        "<input type='hidden' name='authenticity_token' value='#{env[:csrf_token]}'/>"
      end

      def poll_path
        "?#{request.query_string}" if safe_url_params("poll")
      end

      def sidekiq_status_template(name)
        path = File.join(VIEW_PATH, name.to_s) + ".erb"
        File.open(path).read
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
        when 'complete', 'failed', 'stopped', 'interrupted'
          ended = Sidekiq::Status.ended_at(status['jid'])
          started = Sidekiq::Status.started_at(status['jid'])
          ended && started ? ended - started : nil
        when 'working', 'retrying'
          Time.now.to_i - Sidekiq::Status.started_at(status['jid'])
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
          'primary'
        else
          'danger'
        end
      end

      def has_sort_by?(value)
        ["worker", "status", "updated_at", "pct_complete", "message", "args", "elapsed"].include?(value)
      end

      def retry_job_action
        job = Sidekiq::RetrySet.new.find_job(safe_url_params("jid"))
        job ||= Sidekiq::DeadSet.new.find_job(safe_url_params("jid"))
        job.retry if job
        throw :halt, [302, { "Location" => request.referer }, []]
      end

      def delete_job_action
        Sidekiq::Status.delete(safe_url_params("jid"))
        throw :halt, [302, { "Location" => request.referer }, []]
      end
    end
  end
end
