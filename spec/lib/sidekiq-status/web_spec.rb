require 'spec_helper'
require 'sidekiq-status/web'
require 'rack/test'
require 'base64'

describe 'sidekiq status web' do
  include Rack::Test::Methods

  let!(:redis) { Sidekiq.redis { |conn| conn } }
  let!(:job_id) { SecureRandom.hex(12) }

  def app
    @app ||= Sidekiq::Web.new
  end

  before do
    allow(SecureRandom).to receive(:hex).and_return(job_id)
    # Set up a basic session for Sidekiq's CSRF protection
    env 'rack.session', {}
    client_middleware
  end

  around { |example| start_server(&example) }

  it 'shows the list of jobs in progress' do
    capture_status_updates(2) do
      expect(LongJob.perform_async(0.5)).to eq(job_id)
    end

    get '/statuses'
    expect(last_response).to be_ok
    expect(last_response.body).to match(/#{job_id}/)
    expect(last_response.body).to match(/LongJob/)
    expect(last_response.body).to match(/working/)
  end

  it 'allows filtering the list of jobs by status' do
    capture_status_updates(2) do
      LongJob.perform_async(0.5)
    end

    get '/statuses?status=working'
    expect(last_response).to be_ok
    expect(last_response.body).to match(/#{job_id}/)
    expect(last_response.body).to match(/LongJob/)
    expect(last_response.body).to match(/working/)
  end

  it 'allows filtering the list of jobs by completed status' do
    capture_status_updates(2) do
      LongJob.perform_async(0.5)
    end
    get '/statuses?status=completed'
    expect(last_response).to be_ok
    expect(last_response.body).to_not match(/LongJob/)
  end

  it 'shows a single job in progress' do
    capture_status_updates(2) do
      LongJob.perform_async(1, 'another argument')
    end

    get "/statuses/#{job_id}"
    expect(last_response).to be_ok
    expect(last_response.body).to match(/#{job_id}/)
    expect(last_response.body).to match(/1,&quot;another argument&quot;/)
    expect(last_response.body).to match(/working/)
  end

  it 'shows custom data for a single job' do
    capture_status_updates(3) do
      CustomDataJob.perform_async
    end

    get "/statuses/#{job_id}"
    expect(last_response).to be_ok
    expect(last_response.body).to match(/mister_cat/)
    expect(last_response.body).to match(/meow/)
  end

  it 'show an error when the requested job ID is not found' do
    get '/statuses/12345'
    expect(last_response).to be_not_found
    expect(last_response.body).to match(/That job can't be found/)
  end

  it 'handles POST with PUT method override for retrying failed jobs' do
    # Create a failed job first
    capture_status_updates(3) do
      FailingJob.perform_async
    end

    # First make a GET request to establish the session and get the CSRF token
    get '/statuses'
    expect(last_response).to be_ok

    # Extract the CSRF token from the environment
    csrf_token = last_request.env[:csrf_token]

    # Simulate the retry form submission with a referer header
    header 'Referer', 'http://example.com/statuses'
    post '/statuses', {
      'jid' => job_id,
      '_method' => 'put',
      'authenticity_token' => csrf_token
    }

    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq('http://example.com/statuses')
  end

  it 'handles POST with DELETE method override for removing completed jobs' do
    # Create a completed job first
    capture_status_updates(2) do
      StubJob.perform_async
    end

    # First make a GET request to establish the session and get the CSRF token
    get '/statuses'
    expect(last_response).to be_ok

    # Extract the CSRF token from the environment
    csrf_token = last_request.env[:csrf_token]

    # Simulate the remove form submission with a referer header
    header 'Referer', 'http://example.com/statuses'
    post '/statuses', {
      'jid' => job_id,
      '_method' => 'delete',
      'authenticity_token' => csrf_token
    }

    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq('http://example.com/statuses')
    expect(Sidekiq::Status.status(job_id)).to be_nil
  end

  it 'returns 405 for POST without valid method override' do
    # First make a GET request to establish the session and get the CSRF token
    get '/statuses'
    expect(last_response).to be_ok

    # Extract the CSRF token from the environment
    csrf_token = last_request.env[:csrf_token]

    post '/statuses', {
      'jid' => job_id,
      'authenticity_token' => csrf_token
    }

    expect(last_response.status).to eq(405)
  end
end
