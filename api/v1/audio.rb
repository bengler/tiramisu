require 'cgi'
require 'timeout'
require "tiramisu/s3_file"
require "pebbles-uid"

class TiramisuV1 < Sinatra::Base

  # @apidoc
  # Post a job to transcode and store an audio file.
  #
  # @category Tiramisu
  # @path /api/tiramisu/v1/audio_files
  # @http POST
  # @example /api/tiramisu/v1/audio_files/track:acme.myapp file?File:/asdfasdf
  # @required [String] uid The partial Pebbles Uid (species:path, without oid).
  # @status 200 A stream of JSON objects that describe the status of the transfer.
  #   When status is 'completed', an additional key, 'metadata' will be present containing data about the transcoded
  #   formats urls of transcoded files.
  post '/audio_files/:uid' do |uid|

    response['X-Accel-Buffering'] = 'no'
    response.status = 200 # must be 200 or the browser *may* not start reading from the response immediately (not verified).
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
      progress.received

      # Generate a new image bundle and upload the original image to it.
      begin

        ensure_file

        uploaded_file = params[:file][:tempfile]

        base_uid = Pebbles::Uid.new(uid)
        s3_file = S3AudioFile.create(base_uid, :filename => params[:file][:filename])

        # Upload file to Amazon S3.
        asset_store.put s3_file.path, (Interceptor.wrap(uploaded_file, :read) do |file, method|
          # Reports progress as a number between 0 and 1 as the original file is uploaded to S3.
          progress.transferring(file.pos.to_f/file.size.to_f)
        end)

        bundle = AudioBundle.new(asset_store, s3_file)
        job = bundle.to_tootsie_job

        job[:notification_url] = params[:notification_url] if params[:notification_url]

        pebbles.tootsie.post("/jobs", job)

        progress.completed :metadata => bundle.metadata

      rescue MissingUploadedFileError => e
        progress.failed('missing-uploaded-file')
        LOGGER.warn e.message
        LOGGER.error e
      rescue => e
        progress.failed e.message
        LOGGER.warn e.message
        LOGGER.error e
      end
    end
  end

  # @apidoc
  # Get transcoding status of uploaded audio file.
  #
  # @category Tiramisu
  # @path /api/tiramisu/v1/audio_files/:uid/status
  # @http GET
  # @example /api/tiramisu/v1/audio_files/track:acme.myapp$20120920084923-32423-wav-is-a-title/status
  # @required [String] uid The complete Pebbles uid (including oid).
  # @status 200 A JSON structure that is exactly like the metadata key returned from the upload endpoint, except with an
  #   appended 'ready' key which is true if the transcoding is completed or false if it is in progress.
  get '/audio_files/:uid/status' do |uid|
    uid = Pebbles::Uid.new(uid)
    begin
      s3_file = S3AudioFile.new(uid)
    rescue S3File::IncompleteUidError => e
      halt 400, "Incomplete uid: #{e.message}"
    end
    bundle = AudioBundle.new(asset_store, s3_file)

    data = bundle.metadata

    client = HTTPClient.new
    data[:versions].each do |version|
      version[:ready] = (200...300).include? client.head(version[:url]).status_code
    end
    content_type :json
    data.to_json
  end
end
