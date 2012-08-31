require 'simplecov'

SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

$:.unshift(File.dirname(File.dirname(__FILE__)))

ENV["RACK_ENV"] = "test"
require 'config/environment'

require 'rack/test'

require 'api/v1'

require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data("<TIRAMISU S3 KEY>") { ENV.fetch('TIRAMISU_S3_KEY') }
  c.filter_sensitive_data("<TIRAMISU S3 SECRET KEY>") { ENV.fetch('TIRAMISU_S3_SECRET_KEY') }
  c.filter_sensitive_data("<TIRAMISU S3 BUCKET>") { ENV.fetch('TIRAMISU_S3_BUCKET') }
end

set :environment, :test
