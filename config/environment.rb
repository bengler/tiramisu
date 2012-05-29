require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

Dir.glob('./lib/**/*.rb').each { |lib| require lib }

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

require "config/logging"
