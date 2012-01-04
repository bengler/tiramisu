require "bundler"
Bundler.require

# $memcached = Dalli::Client.new

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']


