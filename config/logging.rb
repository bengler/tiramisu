require "logger"

Log = LOGGER if defined?(LOGGER)

unless defined?(Log)
  FileUtils.mkdir('log') unless File.exists?('log')
  Log = Logger.new("log/#{ENV['RACK_ENV']}.log")
end
