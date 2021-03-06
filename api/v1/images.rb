require 'cgi'
require 'timeout'

ORIENTATION_IDS = %w(top-left top-right bottom-right bottom-left left-top right-top right-bottom left-bottom)

class TiramisuV1 < Sinatra::Base

  SUPPORTED_FORMATS = %w(png jpeg jpg bmp gif tiff gif psd)

  # Do not transcode these formats to jpeg
  KEEP_FORMATS = %w(png gif)

  class EmptyFileError < Exception; end
  class UnsupportedFormatError < Exception; end
  class MissingUploadedFileError < Exception; end
  class InvalidParameterError < Exception; end

  # @apidoc
  # Post a job to scale and store an image.
  #
  # @category Tiramisu
  # @path /api/tiramisu/v1/images/:uid
  # @http POST
  # @example /api/tiramisu/v1/images/image:acme.myapp file?File
  #
  # @required [String] uid The partial Pebbles uid (species:path, without oid).
  # @required [File] file Multipart form field containing the image to upload.
  # @optional [String] notification_url The endpoint where you wish to receive notification
  #   when the transfer and scaling job has been completed.
  # @optional [boolean] force_jpeg Will convert all sizes/versions to jpeg. Defaults to true. Set this to false
  #   in order to support gif and png transcoding
  # @optional [string] force_orientation Will force set an orientation on image
  # @status 200 A stream of JSON objects that describe the status of the transfer.
  #   When status is 'completed' an additional key, 'metadata' will be present containing the full uid
  #   as well as information about sizes, aspect ratio, and the paths to the stored images.
  #   On error, the response will be JSON containing the error message. The status will always be 200.
  post '/images/:uid' do |uid|

    LOGGER.info "Received uploaded image #{uid}"

    # Tell web server not to buffer response
    response['X-Accel-Buffering'] = 'no'

    # must be 200 or the browser *may* not start reading from the response immediately (not verified).
    response.status = 200

    if request.user_agent =~ /MSIE/
      content_type request.params['postmessage'] == 'true' ? 'text/html' : 'text/plain'
    end

    stream_file do |progress|
      LOGGER.info 'Started streaming response'

      progress.received

      # Generate a new image bundle and upload the original image to it.
      begin

        ensure_file

        uploaded_file = params[:file][:tempfile]
        filename = params[:file][:filename]
        force_jpeg = params[:force_jpeg] != 'false'

        force_orientation = params.include?('force_orientation') && params['force_orientation']

        if force_orientation
          LOGGER.info "Forcing orientation #{force_orientation} on uploaded file"
          unless ORIENTATION_IDS.include?(force_orientation)
            raise InvalidParameterError, "Invalid orientation '#{force_orientation}'. Must be one of #{ORIENTATION_IDS}"
          end
          ImageUtil.force_orientation_on_file(uploaded_file.path, force_orientation)
        end

        LOGGER.info 'Getting info about uploaded file'
        format, width, height, aspect_ratio = ImageUtil.sanitized_image_info(uploaded_file.path)

        if format.nil? or not SUPPORTED_FORMATS.include?(format.downcase)
          raise UnsupportedFormatError, "Format '#{format}' not supported"
        end

        format = 'jpeg' if force_jpeg or !KEEP_FORMATS.include?(format)
        base_uid = Pebbles::Uid.new(uid)
        s3_file = S3ImageFile.create(base_uid,
                                     :original_extension => File.extname(filename).slice(1..-1),
                                     :aspect_ratio => aspect_ratio)

        LOGGER.info 'Transferring image to S3...'
        # Upload file to Amazon S3.
        asset_store.put s3_file.path, (Interceptor.wrap(File.open(uploaded_file), :read) do |file|
          # Reports progress as a number between 0 and 1 as the original file is uploaded to S3.
          raise(EmptyFileError, "Empty file recieved #{filename}") if file.size == 0
          progress.transferring(file.pos.to_f/file.size)
        end)
        LOGGER.info '... Done!'

        bundle = ImageBundle.new(asset_store, s3_file, {
          format: format,
          height: height,
          width: width,
          aspect_ratio: aspect_ratio
        })
        job = bundle.to_tootsie_job
        job[:notification_url] = params[:notification_url] if params[:notification_url]

        LOGGER.info 'Posting transcoding job to tootsie'
        pebbles.tootsie.post("/jobs", job)
        LOGGER.info '... Done!'


        LOGGER.info 'Closing down response stream!'
        progress.completed :metadata => bundle.metadata

      rescue UnsupportedFormatError => e
        progress.failed('format-not-supported')
        message = "#{e.message} filename: #{filename} uploaded_file: #{uploaded_file}"
        LOGGER.warn message
        LOGGER.error e
      rescue EmptyFileError => e
        progress.failed('empty-file')
        message = "#{e.message} filename: #{filename} uploaded_file: #{uploaded_file}"
        LOGGER.warn message
        LOGGER.error e
      rescue MissingUploadedFileError => e
        progress.failed('missing-uploaded-file')
        message = "#{e.message}. #{request.inspect}"
        LOGGER.warn message
        LOGGER.respond_to?(:exception) ? LOGGER.exception(e) : LOGGER.error(e)
      rescue => e
        progress.failed e.message
        LOGGER.warn e.message
        LOGGER.respond_to?(:exception) ? LOGGER.exception(e) : LOGGER.error(e)
      end
    end
  end


  # @apidoc
  # Delete a single image from S3.
  #
  # @category Tiramisu
  # @path /api/tiramisu/v1/images/:path
  # @http DELETE
  #
  # @required [String] path The whole image URL minus hostname, e.g. apdm/oa/kittens/20160208121232-809-a5x0/original.jpg.
  # @example /api/tiramisu/v1/images
  # @status 200 [JSON] {deleted: true} if the delete operation succeeded, else an error message.
  delete '/images' do
    content_type 'application/json', :charset => 'utf-8'

    path = params[:path]
    halt 400, {error: 'no path'}.to_json unless path
    path = path.sub(/^\w+\.o5\.no\//, '') # new paths are prefixed by bucket name
    realm = path.split('/').first
    halt 403, {error: "You must be god to delete #{path} from #{realm}"}.to_json unless identity_is_god? realm

    begin
      # Delete file from Amazon S3.
      delete_ok = asset_store.delete path
      halt 200, {deleted: delete_ok}.to_json

    rescue S3::Error::NoSuchKey => e
      message = "Unknown image: #{path}"
      LOGGER.warn message
      halt 404, {error: message}.to_json

    rescue S3::Error::AccessDenied => e
      message = "S3 sez access denied for path: #{path}. Key/bucket trouble?"
      LOGGER.warn message
      halt 403, {error: message}.to_json
    end
  end

end
