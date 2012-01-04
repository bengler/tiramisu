# encoding: utf-8
require "json"
require "pebblebed/sinatra"

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class TiramisuV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed
  i_am :tiramisu

  set :config, YAML::load(File.open("config/services.yml"))[ENV['RACK_ENV']]

  helpers do
    def asset_store
      Thread.current[:asset_store] ||= AssetStore.new(settings.config['S3'])
    end

    def progress
      Thread.current[:progress_tracker] ||= ProgressTracker.new(Dalli::Client.new(settings.config['memcached']))
    end

    def tootsie(pipeline)
      Thread.current[:tootsie_pipelines] ||= {}
      Thread.current[:tootsie_pipelines][pipeline.to_sym] ||= TootsiePipeline.new(
        :server => settings.config['tootsie'][pipeline.to_s],
        :bucket => settings.config['S3']['bucket'])
    end
  end

  get '/progress' do
    haml :progress
  end

  get '/tick' do
    response['X-Accel-Buffering'] = 'no' # prevent buffering in proxy server

    expires -1, :public, :must_revalidate

    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream do |out|
      out << " " * 256  if request.user_agent =~ /MSIE/ # ie need ~ 250 k of prelude before it starts flushing the response buffer

      i = 0
      while i <= 100 do
        i += rand(5)
        out << "#{i};#{[i,100].min()}% (#{i < 15 ? 4 : i < 35 ? 3 : i < 80 ? 2 : 1} av 4 operasjoner gjenstår)\n"
        #out << "#{i}\r\n"
        sleep 0.1
      end
    end
  end
end
