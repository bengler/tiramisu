require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  # POST /images/:uid
  # +file+ multipart post
  # -notification_url-

  post '/images/:id' do |id|
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')

    response['X-Accel-Buffering'] = 'no'
    response.status = 201
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream do |out|
      out << " " * 256  if request.user_agent =~ /MSIE/ # ie need ~ 250 k of prelude before it starts flushing the response buffer

      progress = Progress.new(out)
      progress.received

      # Generate a new image bundle and upload the original image to it
      begin
        intercepted_file = Interceptor.wrap(params[:file][:tempfile]) do |file, method, args|
          progress.transferring(file.pos.to_f/file.size) # <- reports progress as a number between 0 and 1 as the original file is uploaded to S3
        end
        bundle = ImageBundle.create_from_file(
          :store => asset_store,
          :file => intercepted_file,
          :location => location
        )
        # Submit image scaling job to tootsie
        bundle.generate_sizes(
          :server => settings.config['tootsie'],
          :notification_url => params[:notification_url])

          progress.completed :image => bundle.image_data
      rescue ImageBundle::FormatError => e
        progress.failed('format-not-supported')
      rescue => e
        progress.failed e.message
      end
      # IE strips off whitespace at the end of an iframe
      # so we need to send a terminator
      out << ";" if request.user_agent =~ /MSIE/ # Damn you, IE...
    end
  end
end
