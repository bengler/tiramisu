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

    response['X-Accel-Buffering'] = 'no'
    response.status = 200 # Must be 200, or else the browser *may* not start reading from the response immediately (not verified).
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
      progress.received

      # Generate a new image bundle and upload the original image to it.
      begin

        ensure_file

        uploaded_file = params[:file][:tempfile]
        filename = params[:file][:filename]

        format, aspect_ratio = image_info(uploaded_file)

        if format.nil? or not SUPPORTED_FORMATS.include?(format.downcase)
          raise UnsupportedFormatError, "Format '#{format}' not supported"
        end

        base_uid = Pebbles::Uid.new(uid)
        s3_file = S3ImageFile.create(base_uid, :filename => filename, :aspect_ratio => aspect_ratio)

        # Upload file to Amazon S3.
        asset_store.put s3_file.path, (Interceptor.wrap(params[:file][:tempfile], :read) do |file|
          # Reports progress as a number between 0 and 1 as the original file is uploaded to S3.
          progress.transferring(file.pos.to_f/file.size)
        end)

        bundle = ImageBundle.new(asset_store, s3_file)
        job = bundle.to_tootsie_job
        job[:notification_url] = params[:notification_url] if params[:notification_url]

        pebbles.tootsie.post("/jobs", job)

        progress.completed :metadata => bundle.metadata

      rescue UnsupportedFormatError => e
        progress.failed('format-not-supported')
        LOGGER.warn e.message
        LOGGER.error e
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
  
  get "/images/:uid/metadata" do |uid|
    [200, ImageBundle.new(asset_store, S3ImageFile.new(Pebbles::Uid.new(uid))).metadata.to_json]
  end

  private
  def image_info(file)
    extension, width, height = `identify -format '%m %w %h' #{file.path} 2> /dev/null`.split(/\s+/)
    [extension, (width && height && width.to_f / height.to_f) || 0]
  end
end
