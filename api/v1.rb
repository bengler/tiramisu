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

  get '/test' do
    haml :test, :locals => {:uploader => params[:uploader] || 'FileUploader'}
  end

  post '/upload' do
    response['X-Accel-Buffering'] = 'no' # prevent buffering in proxy server
    raise "Random error" if rand(2) == 1
    {:status => 201, :responseText => "Upload ok!"}.to_json
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
        sleep 0.1
      end
    end
  end

  get '/ping' do
    begin
      carrot = Carrot.new
      queue = Carrot.queue('ping')
      queue.purge
      queue.publish('ping')
      unless queue.pop == 'ping'
        raise Exception.new("RabbitMQ: Unable to process messages.")
      end
      carrot.stop
    rescue Exception => e
      halt 503, "RabbitMQ: #{e.message}"
    else
      halt 200, "tiramisu"
    end
  end
end
