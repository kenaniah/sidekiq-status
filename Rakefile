#!/usr/bin/env rake

require "bundler/setup"
require "bundler/gem_tasks"

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
task :test => :spec

task :default => :spec

desc "Launch a minimal server with Sidekiq UI at /sidekiq"
task :server do
  require 'webrick'
  require 'rack'
  require 'rack/session'
  require 'stringio'
  require 'sidekiq'
  require 'sidekiq/web'
  require 'sidekiq-status'

  # Create a Rack application
  app = Rack::Builder.new do
    # Add session middleware for Sidekiq::Web CSRF protection
    use Rack::Session::Cookie,
        secret: ENV['SESSION_SECRET'] || 'development_secret_key_that_is_definitely_long_enough_for_rack_session_cookie_middleware',
        same_site: true,
        max_age: 86400

    map "/sidekiq" do
      run Sidekiq::Web
    end

    map "/" do
      run lambda { |env|
        [
          200,
          { 'Content-Type' => 'text/html' },
          [<<~HTML
            <!DOCTYPE html>
            <html>
            <head>
              <title>Sidekiq Status Server</title>
            </head>
            <body>
              <h1>Sidekiq Status Server</h1>
              <p>The Sidekiq web interface is available at <a href="/sidekiq">/sidekiq</a></p>
            </body>
            </html>
          HTML
          ]
        ]
      }
    end
  end

  puts "Starting server on http://localhost:9292"
  puts "Sidekiq web interface available at http://localhost:9292/sidekiq"
  puts "Press Ctrl+C to stop the server"

  # Use WEBrick with a proper Rack handler
  server = WEBrick::HTTPServer.new(Port: 9292, Host: '0.0.0.0')

  # Mount the Rack app properly
  server.mount_proc '/' do |req, res|
    begin
      # Construct proper Rack environment
      env = {
        'REQUEST_METHOD' => req.request_method,
        'PATH_INFO' => req.path_info || req.path,
        'QUERY_STRING' => req.query_string || '',
        'REQUEST_URI' => req.request_uri.to_s,
        'HTTP_HOST' => req.host,
        'SERVER_NAME' => req.host,
        'SERVER_PORT' => req.port.to_s,
        'SCRIPT_NAME' => '',
        'rack.input' => StringIO.new(req.body || ''),
        'rack.errors' => $stderr,
        'rack.version' => [1, 3],
        'rack.url_scheme' => 'http',
        'rack.multithread' => true,
        'rack.multiprocess' => false,
        'rack.run_once' => false
      }

      # Add request headers to environment
      req.header.each do |key, values|
        env_key = key.upcase.tr('-', '_')
        env_key = "HTTP_#{env_key}" unless %w[CONTENT_TYPE CONTENT_LENGTH].include?(env_key)
        env[env_key] = values.first if values.any?
      end

      # Call the Rack app
      status, headers, body = app.call(env)

      # Set response
      res.status = status
      headers.each { |k, v| res[k] = v } if headers

      # Handle response body
      if body.respond_to?(:each)
        body_content = ""
        body.each { |chunk| body_content << chunk.to_s }
        res.body = body_content
      else
        res.body = body.to_s
      end

    rescue => e
      res.status = 500
      res['Content-Type'] = 'text/plain'
      res.body = "Internal Server Error: #{e.message}"
      puts "Error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

  trap('INT') { server.shutdown }

  begin
    server.start
  rescue Interrupt
    puts "\nServer stopped."
  end
end

desc "Starts an IRB session with Sidekiq, Sidekiq::Status, and the testing jobs loaded"
task :irb do
  require 'irb'
  require 'sidekiq-status'
  require_relative 'spec/support/test_jobs'

  Sidekiq.configure_server do |config|
    Sidekiq::Status.configure_server_middleware config
  end

  # Configure Sidekiq if needed
  Sidekiq.configure_client do |config|
    Sidekiq::Status.configure_client_middleware config
    config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379' }
  end

  puts "="*60
  puts "IRB Session with Sidekiq Status"
  puts ""
  puts "To launch a sidekiq worker, run:"
  puts "  bundle exec sidekiq -r ./spec/environment.rb"
  puts ""
  puts "="*60
  puts "Available job classes:"
  puts "  StubJob, LongJob, DataJob, ProgressJob,"
  puts "  FailingJob, ExpiryJob, etc."
  puts ""
  puts "Example usage:"
  puts "  job_id = StubJob.perform_async"
  puts "  job_id = LongJob.perform_async(0.5)"
  puts "  Sidekiq::Status.status(job_id)"
  puts "  Sidekiq::Status.get_all"
  puts "="*60
  puts ""

  ARGV.clear # Clear ARGV to prevent IRB from trying to parse them
  IRB.start
end
