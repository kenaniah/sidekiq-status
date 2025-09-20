module Sidekiq::Status
  module Web
    module Helpers
      COMMON_STATUS_HASH_KEYS = %w(update_time jid status worker args label pct_complete total at message working_at elapsed eta)

        def csrf_tag
          "<input type='hidden' name='authenticity_token' value='#{env[:csrf_token]}'/>"
        end

        def poll_path
          "?#{request.query_string}" if params[:poll]
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
            'primary'
          else
            'danger'
          end
        end

        def has_sort_by?(value)
          ["worker", "status", "update_time", "pct_complete", "message", "args"].include?(value)
        end

        def retry_job_action
          job = Sidekiq::RetrySet.new.find_job(params[:jid])
          job ||= Sidekiq::DeadSet.new.find_job(params[:jid])
          job.retry if job
          throw :halt, [302, { "Location" => request.referer }, []]
        end

        def delete_job_action
          Sidekiq::Status.delete(params[:jid])
          throw :halt, [302, { "Location" => request.referer }, []]
        end
    end
  end
end
