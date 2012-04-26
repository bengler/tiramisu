require "sinatra/reloader"

class ExamplesV1 < Sinatra::Base

  set :root, File.join(File.dirname(__FILE__), "v1")
  
  register Sinatra::Reloader

  helpers do
    include Sprockets::Helpers
  end

  get "/" do
    %w(image file audio multi).map do |example|
      "<li><a href=\"v1/#{example}\">#{example}</li>"
    end
  end
  get "/:what" do |what|
    haml :"#{what}"
  end
end