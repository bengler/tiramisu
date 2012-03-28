require "sinatra/reloader"

class ExamplesV1 < Sinatra::Base

  set :root, File.dirname(__FILE__)
  #set :haml, :layout => :'layouts/apdm'
  
  register Sinatra::Reloader

  helpers do
    include Sprockets::Helpers
  end

  get "/" do
    %w(image file).map do |example|
      "<li><a href=\"v1/#{example}\">#{example}</li>"
    end
  end
  
  get "/image" do
    haml :image
  end
  
  get "/file" do
    haml :file
  end
  get "/audio" do
    haml :audio
  end
end