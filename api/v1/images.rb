require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  SUPPORTED_FORMATS = %w(png jpeg jpg bmp gif tiff gif pdf psd)

  # Do not transcode these formats to jpeg
  KEEP_FORMATS = %w(png gif)

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
  # @optional [boolean] force_jpeg Will converts all sizes/versions to jpeg. Defaults to true. Set this to false
  #   in order to support gif and png transcoding
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

        LOGGER.info 'Getting info about uploaded file'
        format, width, height, aspect_ratio = image_info(uploaded_file)

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
        asset_store.put s3_file.path, (Interceptor.wrap(params[:file][:tempfile], :read) do |file|
          # Reports progress as a number between 0 and 1 as the original file is uploaded to S3.
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
    halt [400, {error: 'no path'}.to_json] unless path
    halt [403, {error: 'You must be god to delete anything'}.to_json] unless identity_is_god?

    LOGGER.info "Delete image at #{path}"
    # TODO: halt 403 unless god

    begin
      # Delete file from Amazon S3.
      delete_ok = asset_store.delete path
      [200, {deleted: delete_ok}.to_json]

    rescue S3::Error::NoSuchKey => e
      message = "Unknown image: #{path}"
      LOGGER.warn message
      [404, {error: message}.to_json]

    rescue S3::Error::AccessDenied => e
      message = "#{e.message} at S3 for path: #{path}. Key/bucket trouble?"
      LOGGER.warn message
      [403, {error: message}.to_json]

    rescue => e
      LOGGER.warn e.message
      LOGGER.respond_to?(:exception) ? LOGGER.exception(e) : LOGGER.error(e)
    end
  end


  private
  def image_info(file)
    format, width, height, orientation = `identify -format '%m %w %h %[EXIF:Orientation]' #{file.path} 2> /dev/null`.split(/\s+/)
    if [5, 6, 7, 8].include?(orientation.to_i)
      # Adjust for exif orientation
      width, height = height, width
    end

    width = width && width.to_i
    height = height && height.to_i

    [format && format.downcase, width, height, (width && height && width.to_f / height.to_f) || 0]
  end
end
