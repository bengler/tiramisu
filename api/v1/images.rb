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
    response.status = 200 # must be 200, or else the browser *may* not start reading from the response immediately (not verified)
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
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
        bundle.submit_image_scaling_job(
          :server => settings.config['tootsie'],
          :notification_url => params[:notification_url])

          progress.completed :image => bundle.image_data
      rescue ImageBundle::FormatError => e
        progress.failed('format-not-supported')
      rescue => e
        progress.failed e.message
      end
    end
  end
end
