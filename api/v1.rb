# encoding: utf-8
require "json"

Dir.glob("#{File.dirname(__FILE__)}/v1/**/*.rb").each{ |file| require file }

class TiramisuV1 < Sinatra::Base
  set :root, "#{File.dirname(__FILE__)}/v1"

  register Sinatra::Pebblebed
  i_am :tiramisu

  post '/a_resource' do
    require_god
  end

  put '/a_resource/:resource' do |resource|
    require_god
  end

  get '/a_resource/:resource' do |resource|
    require_identity
  end

end
