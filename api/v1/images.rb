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
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream do |out|
      out << " " * 256  if request.user_agent =~ /MSIE/ # ie need ~ 250 k of prelude before it starts flushing the response buffer

      progress = Progress.new(out)
      progress.received

      # Generate a new image bundle and upload the original image to it
      begin
        bundle = ImageBundle.create_from_file(
          :store => asset_store,
          :file => params[:file][:tempfile],
          :location => location
        ) do |percent| # <- reports progress as a number between 0 and 1 as the original file is uploaded to S3
          progress.transferring(percent)
        end
      rescue ImageBundle::FormatError => e
        progress.failed('format-not-supported')
      end

      begin
        # Submit image scaling job to tootsie
        bundle.generate_sizes(
          :server => settings.config['tootsie'],
          :notification_url => params[:notification_url])

          progress.completed :image => bundle.image_data
      rescue => e
        progress.failed e.message
      end
      # IE strips off whitespace at the end of an iframe
      # so we need to send a terminator
      out << ";" if request.user_agent =~ /MSIE/ # Damn you, IE...
    end
  end
end
