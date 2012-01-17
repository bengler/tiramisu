require "bundler"
Bundler.require

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']
