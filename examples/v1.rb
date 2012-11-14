class ExamplesV1 < Sinatra::Base

  set :root, File.join(File.dirname(__FILE__), "v1")

  helpers do
    include Sprockets::Helpers
  end

  get "/" do
    %w(image file audio multi).map do |asset|
      "<li><a href=\"/examples/v1/#{asset}\">#{asset}</li>"
    end
  end

  get "/:asset" do |asset|
    haml asset.to_sym
  end
end
