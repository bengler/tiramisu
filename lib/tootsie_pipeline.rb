# A gob of glue to talk to the transcoding service Tootsie

class Tootsie
  def initialize(options)
    @server = options[:server]
    @bucket = options[:bucket]
  end

  # :source - url of source image
  # :bundle_path - path to image bundle
  # :sizes - sizes to request
  # :notification_url - url tootsie will post response to
  def transcode(params)
    job = {
      :type => 'image',
      :notification_url => params[:notification_url],
      :params => params_for(params[:source], params[:bundle_path], params[:sizes])
    }

    client = HTTPClient.new
    response = client.post("#{@server}/job", job.to_json)
    case response.status_code
    when 200..299
      return true
    else
      puts "HTTP request failed with error #{response.code}"
      return false
    end
  end
  
  def params_for(source, bundle_path, sizes)
    params = {}
    params[:input_url] = source
    params[:versions] = []
    sizes.each do |size|
      params[:versions] << version_options(bundle_path, size)
    end
    params
  end

  def version_options(bundle_path, size)
    options = {
      "format" => "jpeg",
      "target_url" => "s3:#{@bucket}/#{bundle_path}/#{size}.jpg?acl=public_read",
      "strip_metadata" => true,
      "width" => size
    }
    options
  end
end