class TiramisuV1 < Sinatra::Base

  # POST /assets/:uid?transaction_id=abcdef&notification_url=localhost:3000?stuff # asset:realm.application.collection.etc

  post '/assets/:id' do |id|
    response.status = 201
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')
    bundle = ImageBundle.build_from_file(
      :store => asset_store,
      :file => params[:file][:tempfile],
      :location => location
    ) do |progress_fraction|
      # Report progress to possible /transaction/:id/progress clients
      progress.report(params[:transaction_id], (progress_fraction*90).round) if params[:transaction_id]
    end
    # Submission to tootsie and waiting for thumbnail ...
    progress.report(params[:transaction_id], 100)
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
