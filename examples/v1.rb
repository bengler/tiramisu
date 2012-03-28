require "sinatra/reloader"

class ExamplesV1 < Sinatra::Base

  set :root, File.join(File.dirname(__FILE__), "v1")
  
  register Sinatra::Reloader

  helpers do
    include Sprockets::Helpers
  end

  get "/" do
    %w(image document).map do |example|
      "<li><a href=\"v1/#{example}\">#{example}</li>"
    end
  end
  
  get "/image" do
    haml :image
  end
  
  get "/document" do
    haml :document
  end
  get "/audio" do
    haml :audio
  end
end