class TiramisuV1 < Sinatra::Base

  post '/assets/:id' do |id|
    response.status = 201
    asset = Asset.new(id)
    {:image => {
      :id => asset.uid,
      :basepath => asset.basepath,
      :sizes => asset.sizes,
      :original => asset.original_image,
      :aspect => asset.aspect_ratio
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
