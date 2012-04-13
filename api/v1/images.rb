require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  post '/images/:uid' do |uid|

    response['X-Accel-Buffering'] = 'no'
    response.status = 200 # must be 200, or else the browser *may* not start reading from the response immediately (not verified)
    content_type 'text/plain' if request.user_agent =~ /MSIE/

    stream_file do |progress|
      progress.received

      # Generate a new image bundle and upload the original image to it
      begin

        uploaded_file = params[:file][:tempfile]
        filename = params[:file][:filename]

        extension, aspect_ratio = image_info(uploaded_file)
        # todo: check that file is submitted with a valid extension?

        base_uid = Pebblebed::Uid.new(uid)
        s3_file = S3ImageFile.create(base_uid, :filename => filename, :aspect_ratio => aspect_ratio)

        # Upload file to Amazon S3
        asset_store.put s3_file.path, (Interceptor.wrap(params[:file][:tempfile], :read) do |file|
          # Reports progress as a number between 0 and 1 as the original file is uploaded to S3
          progress.transferring(file.pos.to_f/file.size)
        end)

        bundle = ImageBundle.new(asset_store, s3_file)
        job = bundle.to_tootsie_job
        job[:notification_url] = params[:notification_url] if params[:notification_url] 

        TootsieHelper.submit_job settings.config['tootsie'], job

        progress.completed :metadata => bundle.metadata

      rescue ImageBundle::FormatError => e
        progress.failed('format-not-supported')
      rescue => e
        progress.failed e.message
        Log.error e
      end
    end
  end

  private
  def image_info(file)
    extension, width, height = `identify -format '%m %w %h' #{file.path} 2> /dev/null`.split(/\s+/)
    [extension, (width && height && width.to_f / height.to_f) || 0]
  end
end
