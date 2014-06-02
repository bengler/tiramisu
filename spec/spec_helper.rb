require 'simplecov'

SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

$:.unshift(File.dirname(File.dirname(__FILE__)))

ENV["RACK_ENV"] = "test"
require 'config/environment'

require 'rack/test'

require 'lib/tiramisu'
require 'api/v1'

require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data("<TIRAMISU S3 KEY>") { Tiramisu.config['S3']['access_key_id'] }
  c.filter_sensitive_data("<TIRAMISU S3 SECRET KEY>") { Tiramisu.config['S3']['secret_access_key'] }
  c.filter_sensitive_data("<TIRAMISU S3 BUCKET>") { Tiramisu.config['S3']['bucket'] }
end

set :environment, :test
