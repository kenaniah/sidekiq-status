require 'spec_helper'
require 'sidekiq-status/web'
require 'rack/test'
require 'base64'

describe 'sidekiq status web' do
  include Rack::Test::Methods

  let!(:redis) { Sidekiq.redis { |conn| conn } }
  let!(:job_id) { SecureRandom.hex(12) }

  def app
    Sidekiq::Web
  end

  before do
    env 'rack.session', csrf: Base64.urlsafe_encode64('token')
    client_middleware
    allow(SecureRandom).to receive(:hex).and_return(job_id)
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
end
