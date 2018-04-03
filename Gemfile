source 'https://rubygems.org'

gem 'rake', '~> 10.4.2'
gem 'sinatra', '~> 1.4.6'
gem 'sinatra-contrib', '~> 1.4.6'
gem 'rack-contrib', '~> 1.3.0'
gem 'pebblebed', '~> 0.4.4'
gem 'pebbles-cors', :git => "https://github.com/bengler/pebbles-cors"
gem 'pebbles-uid', '~> 0.0.22'
gem 's3', '~> 0.3.22'
gem 'httpclient', '~> 2.6.0.1'
gem 'mimemagic', '~> 0.3.2'

group :development, :test do
  gem 'rspec', '~> 3.3.0'
  gem 'rspec-mocks', '~> 3.3.2'
  gem 'rack-test', '~> 0.6.3'
  gem 'vcr', '~> 2.9.3'
  gem 'webmock', '~> 1.21.0'
  gem 'simplecov', '~> 0.10.0'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '~> 4.9.0'
end
