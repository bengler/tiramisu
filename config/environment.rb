require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

project_dir = File.dirname(File.dirname(__FILE__))
$:.unshift("#{project_dir}/lib")

require 'tiramisu'

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

Pebblebed.config do
  service :tootsie
  service :checkpoint
end

unless defined?(LOGGER)
  require "logger"
  FileUtils.mkdir('log') unless File.exists?('log')
  LOGGER = Logger.new("log/#{ENV['RACK_ENV']}.log")
end
