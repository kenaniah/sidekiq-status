# Sidekiq::Status
[![Gem Version](https://badge.fury.io/rb/sidekiq-status.svg)](https://badge.fury.io/rb/sidekiq-status)
[![Build Status](https://github.com/kenaniah/sidekiq-status/actions/workflows/ci.yaml/badge.svg)](https://github.com/kenaniah/sidekiq-status/actions/)

Sidekiq-status is an extension to [Sidekiq](https://github.com/mperham/sidekiq) that tracks information about your Sidekiq and provides a UI to that purpose. It was inspired by [resque-status](https://github.com/quirkey/resque-status).

Supports Ruby 3.2+ and Sidekiq 7.0+ or newer.

## Table of Contents

- [Installation](#installation)
- [Migration Guides](#migration-guides)
  - [Migrating to Version 4.x from 3.x](#migrating-to-version-4x-from-3x)
  - [Migrating to Version 3.x from 2.x](#migrating-to-version-3x-from-2x)
- [Setup Checklist](#setup-checklist)
- [Configuration](#configuration)
- [Expiration Times](#expiration-times)
- [Retrieving Status](#retrieving-status)
- [ActiveJob Support](#activejob-support)
- [Tracking Progress and Storing Data](#tracking-progress-and-storing-data)
- [Stopping a Running Job](#stopping-a-running-job)
- [Unscheduling Jobs](#unscheduling)
- [Deleting Job Status](#deleting-job-status-by-job-id)
- [Sidekiq Web Integration](#sidekiq-web-integration)
- [Testing](#testing)
- [Development Environment](#development-environment)
- [Testing with Appraisal](#testing-with-appraisal)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-status'
```

Or install it yourself as:

```bash
gem install sidekiq-status
```

## Migration Guides

### Migrating to Version 4.x from 3.x

Version 4.0.0 adds support for Ruby 3.3, 3.4 and Sidekiq 8.x, but drops support for Sidekiq 6.x and Ruby versions that are now end-of-life (specifically, Ruby 2.7.x - Ruby 3.1.x).

Version 4.0.0 introduces a breaking change in the way job timestamps are stored in Redis, and also renames `#working_at` to `#updated_at`. Additionally, this version includes major UI improvements with enhanced progress bars and better web interface styling.

### Migrating to Version 3.x from 2.x

Version 3.0.0 adds support for Sidekiq 7.x, but drops support for Sidekiq 5.x. **You should be able to upgrade cleanly from version 2.x to 3.x provided you are running Sidekiq 6.x or newer.**

#### Migrating to Version 2.x from 1.x

Version 2.0.0 was published in order to add support for Ruby 3.0 and Sidekiq 6.x and to remove support for versions of both that are now end-of-life. **You should be able to upgrade cleanly from version 1.x to 2.x provided you are running Sidekiq 5.x or newer.**

Sidekiq-status version 1.1.4 provides support all the way back to Sidekiq 3.x and was maintained at https://github.com/utgarda/sidekiq-status/.

## Setup Checklist

To get started:

 * [Configure](#configuration) the middleware
 * (Optionally) add the [web interface](#adding-the-web-interface)
 * (Optionally) enable support for [ActiveJob](#activejob-support)

### Configuration

To use, add sidekiq-status to the middleware chains. See [Middleware usage](https://github.com/mperham/sidekiq/wiki/Middleware)
on the Sidekiq wiki for more info.

``` ruby
require 'sidekiq'
require 'sidekiq-status'

Sidekiq.configure_client do |config|
  # accepts :expiration (optional)
  Sidekiq::Status.configure_client_middleware config, expiration: 30.minutes.to_i
end

Sidekiq.configure_server do |config|
  # accepts :expiration (optional)
  Sidekiq::Status.configure_server_middleware config, expiration: 30.minutes.to_i

  # accepts :expiration (optional)
  Sidekiq::Status.configure_client_middleware config, expiration: 30.minutes.to_i
end
```

Include the `Sidekiq::Status::Worker` module in your jobs if you want the additional functionality of tracking progress and storing / retrieving job data.

``` ruby
class MyJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker # enables job status tracking

  def perform(*args)
  # your code goes here
  end
end
```

Note: _only jobs that include `Sidekiq::Status::Worker`_ will have their statuses tracked.

To overwrite expiration on a per-worker basis, write an expiration method like the one below:

``` ruby
class MyJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker # enables job status tracking

  def expiration
    @expiration ||= 60 * 60 * 24 * 30 # 30 days
  end

  def perform(*args)
    # your code goes here
  end
end
```

The job status and any additional stored details will remain in Redis until the expiration time is reached. It is recommended that you find an expiration time that works best for your workload.

### Expiration Times

As sidekiq-status stores information about jobs in Redis, it is necessary to set an expiration time for the data that gets stored. A default expiration time may be configured at the time the middleware is loaded via the `:expiration` parameter.

As explained above, the default expiration may also be overridden on a per-job basis by defining it within the job itself via a method called `#expiration`.

The expiration time set will be used as the [Redis expire time](https://redis.io/commands/expire), which is also known as the TTL (time to live). Once the expiration time has passed, all information about the job's status and any custom data stored via sidekiq-status will disappear.

It is advised that you set the expiration time greater than the amount of time required to complete the job.

The default expiration time is 30 minutes.

### Retrieving Status

Query for job status at any time up to expiration:

```ruby
job_id = MyJob.perform_async(*args)
```

#### Basic Status Queries

```ruby
# Get current status as symbol
status = Sidekiq::Status.status(job_id)
# Returns: :queued, :working, :retrying, :complete, :failed, :stopped, :interrupted, or nil after expiry

# Check specific status with boolean methods
Sidekiq::Status.queued?(job_id)      # true if job is queued
Sidekiq::Status.working?(job_id)     # true if job is currently running
Sidekiq::Status.retrying?(job_id)    # true if job is retrying after failure
Sidekiq::Status.complete?(job_id)    # true if job completed successfully
Sidekiq::Status.failed?(job_id)      # true if job failed permanently
Sidekiq::Status.interrupted?(job_id) # true if job was interrupted
Sidekiq::Status.stopped?(job_id)     # true if job was manually stopped
```

#### Progress and Completion

```ruby
# Get progress information
Sidekiq::Status.at(job_id)           # Current progress (e.g., 42)
Sidekiq::Status.total(job_id)        # Total items to process (e.g., 100)
Sidekiq::Status.pct_complete(job_id) # Percentage complete (e.g., 42)
Sidekiq::Status.message(job_id)      # Current status message
```

#### Timing Information

```ruby
# Get timing data (returns Unix timestamps as integers, or nil)
Sidekiq::Status.enqueued_at(job_id)  # When job was enqueued
Sidekiq::Status.started_at(job_id)   # When job started processing
Sidekiq::Status.updated_at(job_id)   # Last update time
Sidekiq::Status.ended_at(job_id)     # When job finished

# Estimated time to completion (in seconds, or nil)
Sidekiq::Status.eta(job_id)          # Based on current progress rate
```

#### Custom Data Retrieval

```ruby
# Get specific custom field
Sidekiq::Status.get(job_id, :field_name)    # Returns string or nil

# Get all job data as hash
data = Sidekiq::Status.get_all(job_id)
# Returns: {
#   "status" => "working",
#   "updated_at" => "1640995200",
#   "enqueued_at" => "1640995100",
#   "started_at" => "1640995150",
#   "at" => "42",
#   "total" => "100",
#   "pct_complete" => "42",
#   "message" => "Processing...",
#   "custom_field" => "custom_value"
# }
```

**Important:** All status methods return `nil` or `false` after the expiration time.

### ActiveJob Support

This gem also supports ActiveJob jobs. Their status will be tracked automatically.

To also enable job progress tracking and data storage features, simply add the  `Sidekiq::Status::Worker` module to your base class, like below:

```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  include Sidekiq::Status::Worker
end

# app/jobs/my_job.rb
class MyJob < ApplicationJob
  def perform(*args)
    # your code goes here
  end
end
```

### Tracking Progress and Storing Data

Sidekiq-status provides comprehensive progress tracking and custom data storage capabilities for jobs that include the `Sidekiq::Status::Worker` module.

#### Setting Progress

```ruby
class MyJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker # Required for progress tracking

  def perform(*args)
    # Set total number of items to process
    total 100

    # Update progress throughout your job
    (1..100).each do |i|
      # Do some work here...
      sleep 0.1

      # Update progress with optional message
      at i, "Processing item #{i}"
      # This automatically calculates percentage: i/100 * 100
    end
  end
end
```

#### Storing and Retrieving Custom Data

```ruby
class MyJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(user_id, options = {})
    # Store custom data associated with this job
    store user_id: user_id
    store options: options.to_json
    store phase: 'initialization'

    # Store multiple fields at once
    store(
      current_batch: 1,
      batch_size: 50,
      errors_count: 0
    )

    # Retrieve stored data (always returns String or nil)
    stored_user_id = retrieve(:user_id)
    stored_options = JSON.parse(retrieve(:options) || '{}')

    # Update progress and custom data together
    50.times do |i|
      # Do work...

      # Update progress with custom data
      at i, "Processing batch #{i}"
      store current_item: i, last_processed_at: Time.now.to_s
    end

    # Mark different phases
    store phase: 'cleanup'
    at 100, "Job completed successfully"
  end
end

# From outside the job, retrieve custom data
job_id = MyJob.perform_async(123, { priority: 'high' })

# Get specific fields
user_id = Sidekiq::Status.get(job_id, :user_id)              #=> "123"
phase = Sidekiq::Status.get(job_id, :phase)                  #=> "cleanup"
errors = Sidekiq::Status.get(job_id, :errors_count)          #=> "0"

# Get all job data including progress and custom fields
all_data = Sidekiq::Status.get_all(job_id)
puts all_data['phase']                   #=> "cleanup"
puts all_data['current_batch']           #=> "1"
puts all_data['pct_complete']            #=> "100"
```

#### Progress Tracking Patterns

```ruby
class DataImportJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(file_path)
    # Example: Processing a CSV file
    csv_data = CSV.read(file_path)

    # Set total based on data size
    total csv_data.size

    csv_data.each_with_index do |row, index|
      begin
        # Process the row
        process_row(row)

        # Update progress
        at index + 1, "Processed row #{index + 1} of #{csv_data.size}"

        # Store running statistics
        store(
          processed_count: index + 1,
          last_processed_id: row['id'],
          success_rate: calculate_success_rate
        )

      rescue => e
        # Log error but continue processing
        error_count = (retrieve(:error_count) || '0').to_i + 1
        store error_count: error_count, last_error: e.message
      end
    end
  end
end

# Monitor progress from outside
job_id = DataImportJob.perform_async('data.csv')

# Check progress periodically
while !Sidekiq::Status.complete?(job_id) && !Sidekiq::Status.failed?(job_id)
  progress = Sidekiq::Status.pct_complete(job_id)
  message = Sidekiq::Status.message(job_id)
  errors = Sidekiq::Status.get(job_id, :error_count) || '0'

  puts "Progress: #{progress}% - #{message} (#{errors} errors)"
  sleep 1
end
```

#### External Progress Updates

You can also update job progress from outside the worker:

```ruby
# Update progress for any job by ID
job_id = MyJob.perform_async
Sidekiq::Status.store_for_id(job_id, {
  external_update: Time.now.to_s,
  updated_by: 'external_system'
})
```

### Stopping a running job

You can ask a job to stop execution by calling `.stop!` with its job ID. The
next time the job calls `.at` it will raise
`Sidekiq::Status::Worker::Stopped`. It will not attempt to retry.

```ruby
job_id = MyJob.perform_async
Sidekiq::Status.stop!  job_id #=> true
Sidekiq::Status.status job_id #=> :stopped
```

Note this will not kill a running job that is stuck. The job must call `.at`
for it to be stopped in this way.

### Unscheduling

```ruby
scheduled_job_id = MyJob.perform_in 3600
Sidekiq::Status.cancel scheduled_job_id #=> true
# doesn't cancel running jobs, this is more like unscheduling, therefore an alias:
Sidekiq::Status.unschedule scheduled_job_id #=> true

# returns false if invalid or wrong scheduled_job_id is provided
Sidekiq::Status.unschedule some_other_unschedule_job_id #=> false
Sidekiq::Status.unschedule nil #=> false
Sidekiq::Status.unschedule '' #=> false
# Note: cancel and unschedule are alias methods.
```
Important: If you schedule a job and then try any of the status methods after the expiration time, the result will be either `nil` or `false`. The job itself will still be in Sidekiq's scheduled queue and will execute normally. Once the job is started at its scheduled time, sidekiq-status' job metadata will once again be added back to Redis and you will be able to get status info for the job until the expiration time.

### Deleting Job Status by Job ID

Job status and metadata will automatically be removed from Redis once the expiration time is reached. But if you would like to remove job information from Redis prior to the TTL expiration, `Sidekiq::Status#delete` will do just that. Note that this will also remove any metadata that was stored with the job.

```ruby
# returns number of keys/jobs that were removed
Sidekiq::Status.delete(job_id) #=> 1
Sidekiq::Status.delete(bad_job_id) #=> 0
```

### Sidekiq Web Integration

This gem provides a comprehensive extension to Sidekiq's web interface that allows you to monitor job statuses, progress, and custom data in real-time.

#### Features

- **Job Status Dashboard** at `/statuses` - View all tracked jobs
- **Individual Job Details** at `/statuses/:job_id` - Detailed job information
- **Real-time Progress Bars** - Visual progress indicators
- **Custom Data Display** - View all stored job metadata
- **Job Control Actions** - Stop, retry, or delete jobs
- **Responsive Design** - Works on desktop and mobile
- **Dark Mode Support** - Integrates with Sidekiq's theme

![Sidekiq Status Web](web/sidekiq-status-web.png)

The main statuses page shows:
- Job ID and worker class
- Current status with color coding
- Progress bar with percentage complete
- Elapsed time and ETA
- Last updated timestamp
- Custom actions (stop, retry, delete)

![Sidekiq Status Web](web/sidekiq-status-single-web.png)

The individual job page provides:
- Complete job metadata
- Custom data fields
- Detailed timing information
- Full progress history
- Error messages (if failed)

#### Adding the Web Interface

To enable the web interface, require the web module after setting up Sidekiq Web:

```ruby
require 'sidekiq/web'
require 'sidekiq-status/web'

# In Rails, add to config/routes.rb:
mount Sidekiq::Web => '/sidekiq'
```

#### Configuration Options

Customize the web interface behavior:

```ruby
# Configure pagination (default: 25 per page)
Sidekiq::Status::Web.default_per_page = 50
Sidekiq::Status::Web.per_page_opts = [25, 50, 100, 200]

# The web interface will show these options in a dropdown
```

#### Web Interface Security

Since job data may contain sensitive information, secure the web interface:

```ruby
# Example with HTTP Basic Auth
Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(username, ENV['SIDEKIQ_USERNAME']) &&
  ActiveSupport::SecurityUtils.secure_compare(password, ENV['SIDEKIQ_PASSWORD'])
end

# Example with devise (Rails)
authenticate :user, lambda { |u| u.admin? } do
  mount Sidekiq::Web => '/sidekiq'
end
```

**Note:** Only jobs that include `Sidekiq::Status::Worker` will appear in the web interface.

### Testing

Drawing analogy from [sidekiq testing by inlining](https://github.com/mperham/sidekiq/wiki/Testing#testing-workers-inline),
`sidekiq-status` allows to bypass redis and return a stubbed `:complete` status.
Since inlining your sidekiq worker will run it in-process, any exception it throws will make your test fail.
It will also run synchronously, so by the time you get to query the job status, the job will have been completed
successfully.
In other words, you'll get the `:complete` status only if the job didn't fail.

Inlining example:

You can run Sidekiq workers inline in your tests by requiring the `sidekiq/testing/inline` file in your `{test,spec}_helper.rb`:

```ruby
require 'sidekiq/testing/inline'
```

To use `sidekiq-status` inlining, require it too in your `{test,spec}_helper.rb`:

```ruby
require 'sidekiq-status/testing/inline'
```

## Troubleshooting

### Common Issues and Solutions

#### Job Status Always Returns `nil`

**Problem:** `Sidekiq::Status.status(job_id)` returns `nil` even for recent jobs.

**Solutions:**
1. **Verify middleware configuration:**
   ```ruby
   # Make sure both client and server middleware are configured
   Sidekiq.configure_client do |config|
     Sidekiq::Status.configure_client_middleware config
   end

   Sidekiq.configure_server do |config|
     Sidekiq::Status.configure_server_middleware config
     Sidekiq::Status.configure_client_middleware config  # Also needed in server
   end
   ```

2. **Check if job includes the Worker module:**
   ```ruby
   class MyJob
     include Sidekiq::Worker
     include Sidekiq::Status::Worker  # This is required!
   end
   ```

3. **Verify Redis connection:**
   ```ruby
   # Test Redis connectivity
   Sidekiq.redis { |conn| conn.ping }  # Should return "PONG"
   ```

#### Jobs Not Appearing in Web Interface

**Problem:** Jobs are tracked but don't show up in `/sidekiq/statuses`.

**Solutions:**
1. **Include the web module:**
   ```ruby
   require 'sidekiq/web'
   require 'sidekiq-status/web'  # Must be after sidekiq/web
   ```

2. **Check job worker includes status module:**
   ```ruby
   # Only jobs with this module appear in web interface
   include Sidekiq::Status::Worker
   ```

3. **Verify Redis key existence:**
   ```ruby
   # Check if status keys exist in Redis
   Sidekiq.redis do |conn|
     keys = conn.scan(match: 'sidekiq:status:*', count: 100)
     puts "Found #{keys.size} status keys"
   end
   ```

#### Progress Not Updating

**Problem:** Job progress stays at 0% or doesn't update.

**Solutions:**
1. **Call `total` before `at`:**
   ```ruby
   def perform
     total 100    # Set total first
     at 1         # Then update progress
   end
   ```

2. **Use numeric values:**
   ```ruby
   # Correct
   at 50, "Halfway done"

   # Wrong - will not calculate percentage correctly
   at "50", "Halfway done"
   ```

3. **Check for exceptions:**
   ```ruby
   def perform
     total 100
     begin
       at 50
     rescue => e
       puts "Progress update failed: #{e.message}"
     end
   end
   ```

#### Memory Usage Growing Over Time

**Problem:** Redis memory usage increases continuously.

**Solutions:**
1. **Set appropriate expiration:**
   ```ruby
   # Configure shorter expiration for high-volume jobs
   Sidekiq::Status.configure_client_middleware config, expiration: 5.minutes.to_i
   ```

2. **Clean up manually if needed:**
   ```ruby
   # Remove old status data
   Sidekiq.redis do |conn|
     old_keys = conn.scan(match: 'sidekiq:status:*').select do |key|
       conn.ttl(key) == -1  # Keys without expiration
     end
     conn.del(*old_keys) unless old_keys.empty?
   end
   ```

#### Version Compatibility Issues

**Problem:** Errors after upgrading Sidekiq or Ruby versions.

**Solutions:**
1. **Check version compatibility:**
   ```ruby
   # sidekiq-status 4.x requirements:
   # Ruby 3.2+
   # Sidekiq 7.0+

   puts "Ruby: #{RUBY_VERSION}"
   puts "Sidekiq: #{Sidekiq::VERSION}"
   ```

2. **Update gemfile constraints:**
   ```ruby
   gem 'sidekiq', '~> 8.0'  # Use compatible version
   gem 'sidekiq-status'     # Latest version
   ```

3. **Check for breaking changes:**
   - Version 4.x renamed `#working_at` to `#updated_at`
   - Timestamp storage format changed in 4.x

#### ActiveJob Integration Issues

**Problem:** ActiveJob jobs not being tracked.

**Solutions:**
1. **Include module in base class:**
   ```ruby
   class ApplicationJob < ActiveJob::Base
     include Sidekiq::Status::Worker  # Add to base class
   end
   ```

2. **Verify Sidekiq adapter:**
   ```ruby
   # In config/application.rb or config/environments/production.rb
   config.active_job.queue_adapter = :sidekiq
   ```

#### Testing Issues

**Problem:** Tests failing with status-related code.

**Solutions:**
1. **Use testing inline mode:**
   ```ruby
   # In test helper
   require 'sidekiq/testing'
   require 'sidekiq-status/testing/inline'

   Sidekiq::Testing.inline!
   ```

2. **Mock status calls in tests:**
   ```ruby
   # RSpec example
   allow(Sidekiq::Status).to receive(:status).and_return(:complete)
   allow(Sidekiq::Status).to receive(:pct_complete).and_return(100)
   ```

### Performance Considerations

#### High-Volume Job Optimization

For applications processing thousands of jobs:

```ruby
# Use longer expiration to reduce Redis operations
Sidekiq::Status.configure_client_middleware config, expiration: 24.hours.to_i

# Reduce progress update frequency
class HighVolumeJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(items)
    total items.size

    items.each_with_index do |item, index|
      process_item(item)

      # Update progress every 100 items instead of every item
      if (index + 1) % 100 == 0
        at index + 1, "Processed #{index + 1} items"
      end
    end
  end
end
```

#### Redis Optimization

```ruby
# Use Redis pipelining for batch operations
def batch_update_status(job_data)
  Sidekiq.redis do |conn|
    conn.pipelined do |pipeline|
      job_data.each do |job_id, data|
        pipeline.hmset("sidekiq:status:#{job_id}", data.flatten)
      end
    end
  end
end
```

### Getting Help

If you're still experiencing issues:

1. **Check the logs:** Look for Redis connection errors or middleware loading issues
2. **Enable debug logging:** Add `Sidekiq.logger.level = Logger::DEBUG`
3. **Test with minimal example:** Create a simple job to isolate the problem
4. **Check GitHub issues:** Search for similar problems
5. **Create an issue:** Include Ruby/Sidekiq versions, configuration, and error messages

## Development Environment

This project provides multiple ways to set up a consistent development environment with all necessary dependencies.

### Using VS Code Dev Containers (Recommended)

The easiest way to get started is using VS Code with the Dev Containers extension:

1. **Prerequisites:**
   - [VS Code](https://code.visualstudio.com/)
   - [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   - [Docker Desktop](https://www.docker.com/products/docker-desktop)

2. **Setup:**
   ```bash
   git clone https://github.com/kenaniah/sidekiq-status.git
   cd sidekiq-status
   code .  # Open in VS Code
   ```

3. **Launch Container:**
   - When prompted, click "Reopen in Container"
   - Or use Command Palette (`Ctrl+Shift+P`): "Dev Containers: Reopen in Container"

The devcontainer automatically provides:
- **Ruby 3.4** with all required gems
- **Redis 7.4.0** server (auto-started)
- **VS Code extensions**: Ruby LSP, Endwise, Docker support
- **Pre-configured environment** with proper PATH and aliases

### Manual Development Setup

If you prefer a local setup:

1. **Install Dependencies:**
   ```bash
   # Ruby 3.2+ required
   ruby --version  # Verify version

   # Install Redis (macOS)
   brew install redis
   brew services start redis

   # Install Redis (Ubuntu/Debian)
   sudo apt-get install redis-server
   sudo systemctl start redis-server
   ```

2. **Clone and Setup:**
   ```bash
   git clone https://github.com/kenaniah/sidekiq-status.git
   cd sidekiq-status
   bundle install
   ```

### Docker Compose Setup

For a containerized development environment without VS Code:

```bash
# Start development environment
docker compose -f .devcontainer/docker-compose.yml up -d

# Enter the container
docker compose -f .devcontainer/docker-compose.yml exec app bash

# Install dependencies
bundle install

# Stop environment
docker compose -f .devcontainer/docker-compose.yml down
```

## Testing with Appraisal

This project uses [Appraisal](https://github.com/thoughtbot/appraisal) to ensure compatibility across multiple Sidekiq versions. This is crucial because Sidekiq has breaking changes between major versions.

### Supported Versions

Current test matrix includes:
- **Sidekiq 7.0.x** - Stable release
- **Sidekiq 7.3.x** - Recent stable
- **Sidekiq 7.x** - Latest 7.x
- **Sidekiq 8.0.x** - Latest major version
- **Sidekiq 8.x** - Bleeding edge

### Appraisal Workflow

#### 1. Install All Dependencies

```bash
# Install base dependencies
bundle install

# Generate and install appraisal gemfiles
bundle exec appraisal install
```

This creates version-specific Gemfiles in `gemfiles/` directory:
```
gemfiles/
├── sidekiq_7.0.gemfile      # Sidekiq ~> 7.0.0
├── sidekiq_7.3.gemfile      # Sidekiq ~> 7.3.0
├── sidekiq_7.x.gemfile      # Sidekiq ~> 7
├── sidekiq_8.0.gemfile      # Sidekiq ~> 8.0.0
└── sidekiq_8.x.gemfile      # Sidekiq ~> 8
```

#### 2. Running Tests

**Test all Sidekiq versions:**
```bash
bundle exec appraisal rake spec
```

**Test specific version:**
```bash
# Test against Sidekiq 7.0.x
bundle exec appraisal sidekiq-7.0 rake spec

# Test against Sidekiq 7.3.x
bundle exec appraisal sidekiq-7.3 rake spec

# Test against Sidekiq 8.x
bundle exec appraisal sidekiq-8.x rake spec
```

**Quick test with current Gemfile:**
```bash
bundle exec rake spec
# or
rake spec
```

#### 3. Interactive Debugging

**Start console with specific Sidekiq version:**
```bash
# Debug with Sidekiq 7.0.x dependencies
bundle exec appraisal sidekiq-7.0 irb
```

**Run individual test files:**
```bash
# Test specific file with Sidekiq 8.x
bundle exec appraisal sidekiq-8.x rspec spec/lib/sidekiq-status/worker_spec.rb

# Run with verbose output
bundle exec appraisal sidekiq-8.x rspec spec/lib/sidekiq-status/worker_spec.rb -v
```

#### 4. Updating Dependencies

**Regenerate gemfiles after dependency changes:**
```bash
# Update Appraisals file, then:
bundle exec appraisal generate

# Install new dependencies
bundle exec appraisal install
```

**Update specific version:**
```bash
# Update only Sidekiq 7.x dependencies
bundle exec appraisal sidekiq-7.x bundle update
```

### Testing Best Practices

#### Running Tests in CI/CD Style

```bash
# Full test suite (like GitHub Actions)
bundle exec appraisal install
bundle exec appraisal rake spec

# Check for dependency issues
bundle exec bundle-audit check --update
```

### Common Development Tasks

```bash
# Start Redis for testing
redis-server

# Run Sidekiq worker with test environment
bundle exec sidekiq -r ./spec/environment.rb

# Start IRB with sidekiq-status loaded
bundle exec irb -r ./lib/sidekiq-status

# Generate test coverage report
COVERAGE=true bundle exec rake spec
open coverage/index.html
```

### Docker Development Shortcuts

```bash
# Quick test run using Docker
docker compose run --rm sidekiq-status bundle exec rake spec

# Interactive shell in container
docker compose run --rm sidekiq-status bash

# Test specific Sidekiq version in Docker
docker compose run --rm sidekiq-status bundle exec appraisal sidekiq-8.x rake spec
```

## Contributing

Bug reports and pull requests are welcome. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes along with test cases (`git commit -am 'Add some feature'`)
4. If possible squash your commits to one commit if they all belong to same feature.
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request.

## Thanks
* Pramod Shinde
* Kenaniah Cerny
* Clay Allsopp
* Andrew Korzhuev
* Jon Moses
* Wayne Hoover
* Dylan Robinson
* Dmitry Novotochinov
* Mohammed Elalj
* Ben Sharpe

## License
MIT License, see LICENSE for more details.
© 2012 - 2016 Evgeniy Tsvigun
