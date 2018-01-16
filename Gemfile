source 'https://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'rack-contrib'
gem 'pebblebed', '~> 0.3.25'
gem 'pebbles-cors', :git => "https://github.com/bengler/pebbles-cors"
gem 'pebbles-uid'
gem 's3'
gem 'httpclient'
gem 'mimemagic', '~> 0.3.2'

group :development, :test do
  gem 'rspec'
  gem 'rspec-mocks'
  gem 'rack-test'
  gem 'vcr'
  gem 'webmock'
  gem 'simplecov'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn'
end
