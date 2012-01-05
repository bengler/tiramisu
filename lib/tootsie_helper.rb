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

  private
  
  def self.job_params(options)
    params = {}
    params[:input_url] = options[:source]
    params[:versions] = options[:sizes].map { |size| version_params(options, size) }
    params
  end

  def self.version_params(options, size)
    { "format" => "jpeg",
      "target_url" => "s3:#{options[:bucket]}/#{options[:path]}/#{size}.jpg?acl=public_read",
      "strip_metadata" => true,
      "width" => size
    }
  end
end