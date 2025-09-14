# Sidekiq::Status
[![Gem Version](https://badge.fury.io/rb/sidekiq-status.svg)](https://badge.fury.io/rb/sidekiq-status)
[![Build Status](https://github.com/kenaniah/sidekiq-status/actions/workflows/ci.yaml/badge.svg)](https://github.com/kenaniah/sidekiq-status/actions/)

Sidekiq-status is an extension to [Sidekiq](https://github.com/mperham/sidekiq) that tracks information about your Sidekiq and provides a UI to that purpose. It was inspired by [resque-status](https://github.com/quirkey/resque-status).

Supports Ruby 3.2+ and Sidekiq 6.0+ or newer.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-status'
```

Or install it yourself as:

```bash
gem install sidekiq-status
```

### Migrating to Version 4.x from 3.x (Note... 4.x isn't released yet)

Version 4.0.0 was published in order to add support for Ruby 3.4.x and Sidekiq 8.x and to remove support for Ruby versions of both that are now end-of-life (specifically, Ruby 2.7.x - Ruby 3.1.x). **You should be able to upgrade cleanly from version 3.x to 4.x provided you are running Sidekiq 7.x or newer.**

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

You may query for job status any time up to expiration:

``` ruby
job_id = MyJob.perform_async(*args)
# :queued, :working, :complete, :failed or :interrupted, nil after expiry (30 minutes)
status = Sidekiq::Status::status(job_id)
Sidekiq::Status::queued?      job_id
Sidekiq::Status::working?     job_id
Sidekiq::Status::retrying?    job_id
Sidekiq::Status::complete?    job_id
Sidekiq::Status::failed?      job_id
Sidekiq::Status::interrupted? job_id

```
Important: If you try any of the above status method after the expiration time, the result will be `nil` or `false`.

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

sidekiq-status comes with a feature that allows you to track the progress of a job, as well as store and retrieve any custom data related to a job.

``` ruby
class MyJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker # Important!

  def perform(*args)
    # your code goes here

    # the common idiom to track progress of your task
    total 100 # by default
    at 5, "Almost done" # 5/100 = 5 % completion

    # a way to associate data with your job
    store vino: 'veritas'

    # a way of retrieving stored data
    # remember that retrieved data is always String|nil
    vino = retrieve :vino
  end
end

job_id = MyJob.perform_async(*args)
data = Sidekiq::Status::get_all job_id
data # => {status: 'complete', update_time: 1360006573, vino: 'veritas'}
Sidekiq::Status::get     job_id, :vino #=> 'veritas'
Sidekiq::Status::at      job_id #=> 5
Sidekiq::Status::total   job_id #=> 100
Sidekiq::Status::message job_id #=> "Almost done"
Sidekiq::Status::pct_complete job_id #=> 5
Sidekiq::Status::working_at job_id #=> 2718
Sidekiq::Status::update_time job_id #=> 2819
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

This gem provides an extension to Sidekiq's web interface with an index at `/statuses`.

![Sidekiq Status Web](web/sidekiq-status-web.png)

Information for an individual job may be found at `/statuses/:job_id`.

![Sidekiq Status Web](web/sidekiq-status-single-web.png)

Note: _only jobs that include `Sidekiq::Status::Worker`_ will be reported in the web interface.

#### Adding the Web Interface

To use, setup the Sidekiq Web interface according to Sidekiq documentation and add the `Sidekiq::Status::Web` require:

``` ruby
require 'sidekiq/web'
require 'sidekiq-status/web'
```

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

### Development Environment

This project includes a development container (devcontainer) configuration that provides a consistent development environment with all necessary dependencies pre-installed.

#### Using VS Code Dev Containers

The easiest way to get started is using VS Code with the Dev Containers extension:

1. Install [VS Code](https://code.visualstudio.com/) and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Clone this repository
3. Open the repository in VS Code
4. When prompted, click "Reopen in Container" or use the Command Palette (`Ctrl+Shift+P`) and select "Dev Containers: Reopen in Container"

The devcontainer will automatically:
- Set up Ruby with all required dependencies
- Install and configure Redis
- Run `bundle install` to install gems
- Configure VS Code with recommended extensions and settings

#### Manual Docker Setup

If you prefer not to use VS Code, you can still use the development environment with Docker:

```bash
# Build and start the development environment
docker compose -f .devcontainer/docker-compose.yml up -d

# Enter the development container
docker compose -f .devcontainer/docker-compose.yml exec app bash

# Install dependencies
bundle install
```

### Testing Across Multiple Sidekiq Versions

This project uses [Appraisal](https://github.com/thoughtbot/appraisal) to test against multiple versions of Sidekiq. The gem is configured to test against:

- Sidekiq 6.1.x
- Sidekiq 6.x (latest)
- Sidekiq 7.x (latest)

#### Installing Dependencies for All Versions

To install dependencies for all supported Sidekiq versions:

```bash
# Install appraisal and generate gemfiles
bundle exec appraisal install
```

This will:
1. Install the base dependencies from `Gemfile`
2. Generate specific gemfiles in the `gemfiles/` directory for each Sidekiq version
3. Install dependencies for each version

#### Running Tests

You can run tests in several ways:

**Run tests for all Sidekiq versions:**
```bash
bundle exec appraisal rake spec
```

**Run tests for a specific Sidekiq version:**
```bash
# Test against Sidekiq 6.1
bundle exec appraisal sidekiq-6.1 rake spec

# Test against Sidekiq 6.x
bundle exec appraisal sidekiq-6.x rake spec

# Test against Sidekiq 7.x
bundle exec appraisal sidekiq-7.x rake spec
```

**Run tests using the current Gemfile:**
```bash
bundle exec rake spec
# or simply
rake spec
```

**Quick test run using Docker Compose:**
```bash
docker compose run --rm sidekiq-status
```

#### Updating Gemfiles

When dependencies change, regenerate the appraisal gemfiles:

```bash
bundle exec appraisal generate
```

#### Debugging Test Failures

If tests fail for a specific Sidekiq version, you can debug by running that specific environment:

```bash
# Start a console with Sidekiq 6.1 dependencies
bundle exec appraisal sidekiq-6.1 irb

# Or run a specific test file
bundle exec appraisal sidekiq-6.1 rspec spec/lib/sidekiq-status/worker_spec.rb
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
