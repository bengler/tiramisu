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

  get '/ping' do
    failures = []
    begin
      Carrot.queue('ping')
    rescue Exception => e
      failures << "RabbitMQ: #{e.message}"
    end

    begin
      TootsieHelper.ping(settings.config['tootsie'])
    rescue Exception => e
      failures << "Tootsie: #{e.message}"
    end

    if failures.empty?
      halt 200, "tiramisu"
    else
      halt 503, failures.join("\n")
    end
  end
end
