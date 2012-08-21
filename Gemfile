source 'http://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'rack-contrib', :git => 'https://github.com/rack/rack-contrib.git'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'unicorn', '~> 4.1.1'
gem 'pebblebed'
gem 's3'
gem 'httpclient'
gem 'sprockets', :require => 'sprockets'
gem 'sprockets-helpers', '~> 0.2'
gem 'coffee-script'
gem 'haml'

group :development, :test do
  gem 'bengler_test_helper', :git => "git://github.com/bengler/bengler_test_helper.git", :require => false
  gem 'rspec', '~> 2.8'
  gem 'rack-test'
  gem 'vcr', '~> 2.0.0.rc1'
  gem 'webmock'
  gem 'simplecov'
  gem 'capistrano', '~> 2.9.0', :require => false
  gem 'capistrano-bengler', :git => "git@github.com:bengler/capistrano-bengler.git", :require => false
end
