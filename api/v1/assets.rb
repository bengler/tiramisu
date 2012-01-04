require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  # POST /assets/:uid?transaction_id=abcdef&notification_url=localhost:3000?stuff # asset:realm.application.collection.etc

  post '/assets/:id' do |id|
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')

    bundle = ImageBundle.build_from_file(
      :store => asset_store,
      :file => params[:file][:tempfile],
      :location => location
    ) do |progress_fraction|
      # Report progress to possible /transaction/:id/progress clients, this goes to max 90%
      progress.report(params[:transaction_id], (progress_fraction*90).round) if params[:transaction_id]
    end
    progress.report(params[:transaction_id], 90) if params[:transaction_id]

    # Post the thumbnail job to the tootsie express pipeline
    tootsie(:express).transcode(
      :source => bundle.original_image_url,
      :destination => bundle.path,
      :sizes => [100],
      :notification_url => params[:notification_url]
    )

    # Post the rest of the jobs to the default pipeline
    tootsie(:default).transcode(
      :source => bundle.original_image_url,
      :destination => bundle.path,
      :sizes => [300, 700, 1000],
      :notification_url => params[:notification_url]
    )

    begin
      progress_value = 90
      Timeout::timeout(20) do
        loop do
          sleep 1
          if progress_value < 95 && params[:transaction_id]
            progress_value += 1
            progress.report(params[:transaction_id], progress_value)
          end
          # Waiting for the thumbnail to become availible
          break if bundle.scaled_image_exists?(100)
          sleep 1 # Two seconds between each but not the first time
        end
      end
    rescue Timeout::Error
      halt 408, "Thumbnail did not arrive in time, backend down or overburdened"
    end

    # Just make sure we report 100% completion in the end:
    progress.report(params[:transaction_id], 100) if params[:transaction_id]

    response.status = 201
    {:image => {
      :id => bundle.uid,
      :baseurl => bundle.url,
      :sizes => bundle.sizes,
      :original => bundle.original_image_url,
      :aspect => bundle.aspect_ratio
    }}.to_json
  end

  get '/assets/:id' do |id|
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
