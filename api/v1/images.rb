require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  SUPPORTED_FORMATS = %w(png jpeg jpg bmp gif tiff gif pdf psd)

  class UnsupportedFormatError < Exception; end
  class MissingUploadedFileError < Exception; end

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

        LOGGER.info 'Getting info about uploaded file'
        format, aspect_ratio = image_info(uploaded_file)

        if format.nil? or not SUPPORTED_FORMATS.include?(format.downcase)
          raise UnsupportedFormatError, "Format '#{format}' not supported"
        end

        base_uid = Pebbles::Uid.new(uid)
        s3_file = S3ImageFile.create(base_uid, :filename => filename, :aspect_ratio => aspect_ratio)

        LOGGER.info 'Transferring image to S3...'
        # Upload file to Amazon S3.
        asset_store.put s3_file.path, (Interceptor.wrap(params[:file][:tempfile], :read) do |file|
          # Reports progress as a number between 0 and 1 as the original file is uploaded to S3.
          progress.transferring(file.pos.to_f/file.size)
        end)
        LOGGER.info '... Done!'

        bundle = ImageBundle.new(asset_store, s3_file)
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

  get "/images/:uid/metadata" do |uid|
    content_type :json
    [200, ImageBundle.new(asset_store, S3ImageFile.new(Pebbles::Uid.new(uid))).metadata.to_json]
  end

  private
  def image_info(file)
    extension, width, height, orientation = `identify -format '%m %w %h %[EXIF:Orientation]' #{file.path} 2> /dev/null`.split(/\s+/)
    if [5, 6, 7, 8].include?(orientation.to_i)
      # Adjust for exif orientation
      width, height = height, width
    end
    [extension, (width && height && width.to_f / height.to_f) || 0]
  end
end
