# encoding: utf-8
require "json"
require "pebblebed/sinatra"

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class TiramisuV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed

  set :config, YAML::load(File.open("config/services.yml"))[ENV['RACK_ENV']]

  helpers do
    def asset_store
      Thread.current[:asset_store] ||= AssetStore.new(settings.config['S3'])
    end
  end
end
