require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  # @apidoc
  # Post a job to store a document
  #
  # @category Tiramisu
  # @path /api/tiramisu/v1/files/:uid
  # @http POST
  # @example /api/tiramisu/v1/files/file:acme.myapp file?File:mydocument.pdf
  #
  # @required [String] uid The partial Pebbles Uid (species:path, without oid)
  # @required [File] file Multipart form field containing the file to upload
  # @status 200 A stream of JSON objects that describe the status of the transfer.
  #   When status is 'completed', an additional key, 'metadata' will be present containing full uid, and path to the file.
  #   On error, the response will be JSON containing the error message. The status will always be 200.

  post '/files/:uid' do |uid|
    response['X-Accel-Buffering'] = 'no'
    response.status = 200 # must be 200, or else the browser *may* not start reading from the response immediately (not verified)
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
      progress.received

      begin
        base_uid = Pebbles::Uid.new(uid)
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
