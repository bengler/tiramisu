# A skinny wrapper for the S3-gem

class AssetStore
  attr_reader :bucket

  # options: 'access_key_id', 'secret_access_key', 'bucket_name'
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

  def host
    @bucket.host
  end

  def protocol
    @service.protocol
  end
end