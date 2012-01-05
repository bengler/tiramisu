require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  IMAGE_SIZES = [100, 300, 700, 1000]
  WAIT_FOR_THUMBNAIL_SECONDS = 20

  # POST /images/:uid?transaction_id=abcdef&notification_url=localhost:3000?stuff # asset:realm.application.collection.etc

  post '/images/:id' do |id|
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')

    # The transaction_id is a client provided identifier that represents this upload event
    # and can be used to track the progress of its processing.
    transaction_id = params[:transaction_id]

    # Generate a new image bundle and upload the original image to it
    begin
      bundle = ImageBundle.create_from_file(
        :store => asset_store,
        :file => params[:file][:tempfile],
        :location => location
      ) do |progress| # <- reports progress as the original file is uploaded to S3
        ProgressTracker.report(transaction_id, "#{(progress*90).round};transfering")
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

    # Wait for thumbnail to arrive
    begin
      Timeout::timeout(WAIT_FOR_THUMBNAIL_SECONDS) do
        sleep 1 until bundle.has_size?(IMAGE_SIZES.first)
      end
    rescue Timeout::Error
      ProgressTracker.report(transaction_id, "100;failed")
      halt 408, '{"error":"timeout"}'
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
