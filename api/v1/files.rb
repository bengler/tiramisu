require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  # POST /files/:uid
  # +file+ multipart post

  post '/files/:uid' do |uid|
    klass, path, oid = Pebblebed::Uid.parse(uid)
    location = path.gsub('.', '/')

    response['X-Accel-Buffering'] = 'no'
    response.status = 200 # must be 200, or else the browser *may* not start reading from the response immediately (not verified)
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
      progress.received

      # Generate a new file bundle and upload the original file to it
      begin
        intercepted_file = Interceptor.wrap(params[:file][:tempfile]) do |file, method, args|
          progress.transferring(file.pos.to_f/file.size) # <- reports progress as a number between 0 and 1 as the file is uploaded to S3
        end
        bundle = FileBundle.create_from_file(
            :store => asset_store,
            :file => intercepted_file,
            :format => params[:file][:filename].split(/\./).last,
            :location => location
        )

        progress.completed :file => bundle.file_data
      rescue => e
        progress.failed e.message
      end

    end
  end
end
