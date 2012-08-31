unless defined?(LOGGER)
  require "logger"
  FileUtils.mkdir('log') unless File.exists?('log')
  LOGGER = Logger.new("log/#{ENV['RACK_ENV']}.log")
end
