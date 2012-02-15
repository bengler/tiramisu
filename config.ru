$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'
require 'config/logging'
require 'rack/contrib'

ENV['RACK_ENV'] ||= 'development'
set :environment, ENV['RACK_ENV'].to_sym

use Rack::CommonLogger

map "/api/tiramisu/v1/ping" do
  run Pingable::Handler.new("tiramisu")
end

map "/api/tiramisu/v1" do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  run TiramisuV1
end

map "/api/tiramisu/v1/assets" do

  environment = Sprockets::Environment.new
  environment.append_path 'api/v1/assets'
  Sprockets::Helpers.configure do |config|
    config.environment = environment
    config.prefix = "/api/tiramisu/v1/assets"
    config.digest = false
  end
  run environment
end
