# encoding: utf-8
require "json"
require "pebblebed/sinatra"

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each { |file| require file }

class TiramisuV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed

  set :config, Tiramisu.config

  before do
    # If this service, for some reason, lives behind a proxy that rewrites the Cache-Control headers into
    # "must-revalidate" (which IE9, and possibly other IEs, does not respect), these two headers should properly prevent
    # caching in IE (see http://support.microsoft.com/kb/234067)
    headers 'Pragma' => 'no-cache'
    headers 'Expires' => '-1'
    headers 'X-Frame-Options' => 'ALLOWALL'

    cache_control :private, :no_cache, :no_store, :must_revalidate
  end

  helpers do

    def asset_store
      Thread.current[:asset_store] ||= AssetStore.new(settings.config['S3'])
    end

    def stream_file(&block)
      opts = {
        postmessage: request.params['postmessage'] == 'true'
      }
      stream do |out|
        out << " " * 256 if !opts[:postmessage] && request.user_agent =~ /MSIE/ # ie need ~ 250 k of prelude before it starts flushing the response buffer
        progress = Progress.new(out, opts)
        yield(progress)
        #IE strips off whitespace at the end of an iframe
        #so we need to send a terminator
        out << ";" if !opts[:postmessage] && request.user_agent =~ /MSIE/ # Damn you, IE...
      end
    end

    def identity_is_god?(realm)
      identity = current_identity
      (identity && identity.respond_to?(:god) && identity.god && identity.realm == realm)
    end

  end

  def ensure_file
    # Firefox sends empty string ""
    # Safari and Opera sends "undefined"
    raise MissingUploadedFileError if params[:file].nil? || params[:file] == '' || params[:file] == 'undefined'
  end

end
