source 'https://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'rack-contrib', :git => 'https://github.com/rack/rack-contrib.git'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'pebblebed'
gem 'pebbles-cors', :git => "https://github.com/bengler/pebbles-cors"
gem 'pebbles-uid', '= 0.0.8'
gem 's3'
gem 'httpclient'
gem 'sprockets', :require => 'sprockets'
gem 'sprockets-helpers', '~> 0.2'
gem 'coffee-script'
gem 'haml'
gem 'sass'
gem 'dalli'

group :development, :test do
  gem 'rspec', '~> 2.8'
  gem 'rack-test'
  gem 'vcr', '~> 2.0.0.rc1'
  gem 'webmock'
  gem 'simplecov'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '~> 4.1.1'
end
