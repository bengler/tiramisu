# A skinny wrapper for the S3-gem

class AssetStore
  attr_reader :bucket

  # options: 'access_key_id', 'secret_access_key', 'bucket'
  def initialize(options)
    @service = S3::Service.new(
      :access_key_id => options['access_key_id'],
      :secret_access_key => options['secret_access_key'])
    @bucket = @service.buckets.find(options['bucket'])
  end

  def put(location, content)
    object = @bucket.objects.build(location)
    object.content = content
    object.save
  end

  def delete(path)
    object = @bucket.objects.find(path)
    return object.destroy
  end

  def host
    @bucket.host
  end

  def protocol
    'https://' # used to be @service.protocol, now we always want an https url
  end

  # old: http://apps.o5.no.s3.amazonaws.com/apdm/commercial/sanity/stories/20150701124117-1333-p6q9/2048.jpg
  # new: https://s3-eu-west-1.amazonaws.com/apps.o5.no/apdm/commercial/sanity/stories/20150701124117-1333-p6q9/2048.jpg
  def url_for(path)
    ssl_host = 's3-eu-west-1.amazonaws.com'
    ssl_root_path = host.sub('.s3.amazonaws.com', '')
    "#{protocol}#{ssl_host}/#{ssl_root_path}/#{path}"
  end


  def s3_url_for(path)
    "s3:#{@bucket.name}/#{path}"
  end
end
