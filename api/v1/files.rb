require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  # POST /files/:uid
  # +file+ multipart post

  post '/files/:uid' do |uid|
    response['X-Accel-Buffering'] = 'no'
    response.status = 200 # must be 200, or else the browser *may* not start reading from the response immediately (not verified)
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
      progress.received

      begin
        base_uid = Pebblebed::Uid.new(uid)
        s3_file = S3File.create(base_uid, :filename => params[:file][:filename])

        # Upload file to S3
        asset_store.put s3_file.path, (Interceptor.wrap(params[:file][:tempfile], :read) do |file|
           # reports progress as a number between 0 and 1 as the file is uploaded to S3
          progress.transferring(file.pos.to_f/file.size)
        end)

        progress.completed :metadata => {
          :uid => s3_file.uid,
          :baseurl => asset_store.url_for(s3_file.dirname),
          :original => asset_store.url_for(s3_file.path)
        }
      rescue => e
        progress.failed e.message
        LOGGER.warn e.message
        LOGGER.error e
      end

    end
  end
end
