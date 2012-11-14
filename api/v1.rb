# encoding: utf-8
require "json"
require "pebblebed/sinatra"

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each { |file| require file }

class TiramisuV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed

  set :config, Tiramisu.config

  helpers do

    def asset_store
      Thread.current[:asset_store] ||= AssetStore.new(settings.config['S3'])
    end

    def stream_file(&block)
      stream do |out|
        out << " " * 256 if request.user_agent =~ /MSIE/ # ie need ~ 250 k of prelude before it starts flushing the response buffer
        progress = Progress.new(out)
        yield(progress)
        #IE strips off whitespace at the end of an iframe
        #so we need to send a terminator
        out << ";" if request.user_agent =~ /MSIE/ # Damn you, IE...
      end
    end

  end
end
