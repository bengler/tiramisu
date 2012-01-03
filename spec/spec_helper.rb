require 'simplecov'

SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

$:.unshift(File.dirname(File.dirname(__FILE__)))

ENV["RACK_ENV"] = "test"
require 'config/environment'

# require './spec/mockcached'
require 'rack/test'

require 'api/v1'
require 'config/logging'
require 'timecop'

# require 'vcr'
# VCR.config do |c|
#   c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
#   c.stub_with :webmock
# end

set :environment, :test
