require "logger"

Log = LOGGER if defined?(LOGGER)

# FIXME you guys probably want something different, but had failing tests
Log ||= Logger.new(STDOUT) 
