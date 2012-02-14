require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  # POST /document/:uid
  # +file+ multipart post

  post '/documents/:uid' do |uid|
    klass, path, oid = Pebblebed::Uid.parse(uid)
    location = path.gsub('.', '/')

    response['X-Accel-Buffering'] = 'no'
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream do |out|
      out << " " * 256 if request.user_agent =~ /MSIE/ # ie need ~ 250 k of prelude before it starts flushing the response buffer

      progress = Progress.new(out)
      progress.received

      # Generate a new document bundle and upload the original document to it
      begin
        intercepted_file = Interceptor.wrap(params[:file][:tempfile]) do |file, method, args|
          progress.transferring(file.pos.to_f/file.size) # <- reports progress as a number between 0 and 1 as the file is uploaded to S3
        end
        bundle = DocumentBundle.create_from_file(
            :store => asset_store,
            :file => intercepted_file,
            :format => params[:file][:filename].split(/\./).last,
            :location => location
        )

        progress.completed :document => bundle.document_data
      rescue DocumentBundle::FormatError => e
        progress.failed('format-not-supported')
      end

      # IE strips off whitespace at the end of an iframe
      # so we need to send a terminator
      out << ";" if request.user_agent =~ /MSIE/ # Damn you, IE...
    end
  end
end
