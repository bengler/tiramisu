require "o5-logging"

Log = O5.log
Dalli.logger = O5.log if defined?(Dalli)
