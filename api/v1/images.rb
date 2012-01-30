require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  IMAGE_SIZES = [
    {:width => 100},
    {:width => 100, :square => true},
    {:width => 300},
    {:width => 500, :square => true},
    {:width => 700},
    {:width => 1000},
    {:width => 5000, :medium => 'print'}
  ]

  # POST /images/:uid
  # +file+ multipart post
  # -notification_url-

  post '/images/:id' do |id|
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')

    response['X-Accel-Buffering'] = 'no'
    content_type 'application/octet-stream' if request.user_agent =~ /MSIE/

    stream do |out|
      progress = Progress.new(out)

      begin
        progress.received

        # Generate a new image bundle and upload the original image to it
        begin
          bundle = ImageBundle.create_from_file(
            :store => asset_store,
            :file => params[:file][:tempfile],
            :location => location
          ) do |percent| # <- reports progress as a number between 0 and 1 as the original file is uploaded to S3
            progress.transferring(percent)
          end
        rescue ImageBundle::FormatError => e
          progress.failed('format-not-supported')
          halt 400, 'Format not supported'
        end

        # Submit image scaling job to tootsie
        bundle.generate_sizes(
          :server => settings.config['tootsie'],
          :sizes => IMAGE_SIZES,
          :notification_url => params[:notification_url])

        progress.completed :image => bundle.image_data
       rescue => e
        progress.failed e.message
      end
    end
  end
end
