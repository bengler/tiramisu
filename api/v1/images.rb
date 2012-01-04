require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  # POST /images/:uid?transaction_id=abcdef&notification_url=localhost:3000?stuff # asset:realm.application.collection.etc

  post '/images/:id' do |id|
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')

    # The transaction_id is a client provided identifier that represents this upload event
    # and can be used to track the progress of its processing.
    transaction_id = params[:transaction_id]

    # Generate a new image bundle and upload the original image to it
    bundle = ImageBundle.create_from_file(
      :store => asset_store,
      :file => params[:file][:tempfile],
      :location => location
    ) do |progress_value| # <- reports progress as the original file is uploaded to S3
      progress.report(transaction_id, (progress_value*90).round)
    end

    # Submit thumbnail job to express tootsie pipeline
    bundle.generate_sizes(
      :server => settings.config['tootsie']['express'],
      :sizes => [100],
      :notification_url => params[:notification_url])

    # Submit all other sizes to the default tootsie pipeline
    bundle.generate_sizes(
      :server => settings.config['tootsie']['default'],
      :sizes => [300, 700, 1000],
      :notification_url => params[:notification_url])

    # Wait for thumbnail to arrive
    begin
      Timeout::timeout(20) do
        sleep 1 until bundle.has_size?(100)
      end
    rescue Timeout::Error
      halt 408, "Thumbnail did not arrive in time, backend down or overburdened"
    end
    
    progress.report(transaction_id, 100) # 'cause we're done

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
