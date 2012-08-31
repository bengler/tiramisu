require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

Dir.glob('./lib/**/*.rb').each { |lib| require lib }

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

unless defined?(LOGGER)
  require "logger"
  FileUtils.mkdir('log') unless File.exists?('log')
  LOGGER = Logger.new("log/#{ENV['RACK_ENV']}.log")
end
