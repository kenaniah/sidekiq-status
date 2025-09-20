# -*- encoding: utf-8 -*-
require File.expand_path('../lib/sidekiq-status/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Evgeniy Tsvigun', 'Kenaniah Cerny']
  gem.email         = ['utgarda@gmail.com', 'kenaniah@gmail.com']
  gem.summary       = 'An extension to the sidekiq message processing to track your jobs'
  gem.homepage      = 'https://github.com/kenaniah/sidekiq-status'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'sidekiq-status'
  gem.require_paths = ['lib']
  gem.required_ruby_version = '>= 3.2'
  gem.version       = Sidekiq::Status::VERSION

  gem.add_dependency                  'sidekiq', '>= 7', '< 9'
  gem.add_dependency                  'chronic_duration'
  gem.add_dependency                  'logger'
  gem.add_dependency                  'base64'
  gem.add_development_dependency      'appraisal'
  gem.add_development_dependency      'colorize'
  gem.add_development_dependency      'rack-test'
  gem.add_development_dependency      'rake'
  gem.add_development_dependency      'rspec'
  gem.add_development_dependency      'sinatra'
  gem.add_development_dependency      'webrick'
  gem.add_development_dependency      'rack-session'
end
