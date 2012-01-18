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
  WAIT_FOR_THUMBNAIL_SECONDS = 20

  # POST /images/:uid
  # +file+ multipart post
  # -transaction_id-
  # -notification_url-
  # -wait_for_thumbnail- default: false

  post '/images/:id' do |id|
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')

    # The transaction_id is a client provided identifier that represents this upload event
    # and can be used to track the progress of its processing.
    transaction_id = params[:transaction_id]

    ProgressTracker.report(transaction_id, "0;received")

    # Generate a new image bundle and upload the original image to it
    begin
      bundle = ImageBundle.create_from_file(
        :store => asset_store,
        :file => params[:file][:tempfile],
        :location => location
      ) do |progress| # <- reports progress as the original file is uploaded to S3
        ProgressTracker.report(transaction_id, "#{(progress*90).round};transferring")
      end
    rescue ImageBundle::FormatError => e
      ProgressTracker.report(transaction_id, "100;failed")
      halt 400, '{"error":"format-not-supported"}'
    end

    # Submit image scaling job to tootsie
    bundle.generate_sizes(
      :server => settings.config['tootsie'],
      :sizes => IMAGE_SIZES,
      :notification_url => params[:notification_url])

    ProgressTracker.report(transaction_id, "95;processing")

    unless params[:wait_for_thumbnail] == "false"
      begin
        Timeout::timeout(WAIT_FOR_THUMBNAIL_SECONDS) do
          sleep 1 until bundle.has_size?(IMAGE_SIZES.first)
        end
      rescue Timeout::Error
        ProgressTracker.report(transaction_id, "100;failed")
        halt 408, '{"error":"timeout"}'
      end
    end
    
    ProgressTracker.report(transaction_id, "100;completed") # 'cause we're done

    response.status = 201
    {:image => {
      :id => bundle.uid,
      :baseurl => bundle.url,
      :sizes => bundle.sizes,
      :original => bundle.original_image_url,
      :aspect => bundle.aspect_ratio
    }}.to_json
  end

  get '/images/:id' do |id|
    asset = Asset.new(id)
    {:image => {
      :id => asset.uid,
      :basepath => asset.basepath,
      :sizes => asset.sizes,
      :original => asset.original_image,
      :aspect => asset.aspect_ratio
    }}.to_json
  end
end
