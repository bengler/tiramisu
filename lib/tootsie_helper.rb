# A gob of glue to tack the transcoding service Tootsie to ImageBundle
# without too much cruft.

module TootsieHelper
  # :source - url of source image
  # :path - path to image bundle
  # :sizes - sizes to request
  # :notification_url - url tootsie will post response to
  def self.generate_sizes(server, options)
    job = {
      :type => 'image',
      :notification_url => options[:notification_url],
      :params => job_params(options)
    }

    response = HTTPClient.new.post("#{server}/job", job.to_json)
    unless (200...300).include?(response.status_code)
      raise "Tootsie failed with error #{response.status_code} while submitting job #{job.to_json}."
    end
  end

  def self.ping(server)
    response = HTTPClient.new.head("#{server}/status")
    unless (200...300).include? response.status_code
      raise "/status responded with #{response.status_code}"
    end
  end

  private

  def self.job_params(options)
    params = {}
    params[:input_url] = options[:source]
    params[:versions] = options[:sizes].map { |version| version_params(options, version) }
    params
  end

  def self.version_params(options, version)
    width = version[:width]
    square = version[:square]
    medium = version[:medium] || 'web'
    suffix = square ? 'sq' : ''

    params = {
      "format" => "jpeg",
      "medium" => medium,
      "target_url" => "s3:#{options[:bucket]}/#{options[:path]}/#{width}#{suffix}.jpg?acl=public_read",
      "strip_metadata" => true,
      "width" => width
    }
    if square
      params["scale"] = 'fit'
      params["height"] = width
      params["crop"] = true
    end
    params
  end
end
