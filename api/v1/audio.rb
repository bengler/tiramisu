require 'cgi'
require 'timeout'
require "lib/s3_file"

class TiramisuV1 < Sinatra::Base

  post '/audio_files/:uid' do |uid|

    response['X-Accel-Buffering'] = 'no'
    response.status = 200 # must be 200, or else the browser *may* not start reading from the response immediately (not verified)
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
      progress.received

      # Generate a new image bundle and upload the original image to it
      begin

        uploaded_file = params[:file][:tempfile]

        base_uid = Pebblebed::Uid.new(uid)
        s3_file = S3AudioFile.create(base_uid, :filename => params[:file][:filename])

        # Upload file to Amazon S3
        asset_store.put s3_file.path, (Interceptor.wrap(uploaded_file, :read) do |file, method|
          # Reports progress as a number between 0 and 1 as the original file is uploaded to S3
          progress.transferring(file.pos.to_f/file.size.to_f)
        end)

        bundle = AudioBundle.new(asset_store, s3_file)
        job = bundle.tootsie_job

        job[:notification_url] = params[:notification_url] if params[:notification_url] 

        TootsieHelper.submit_job settings.config['tootsie'], job

        progress.completed :audio_file => bundle.data
  
      rescue => e
        progress.failed e.message
        Log.error e
      end
    end
  end
end
