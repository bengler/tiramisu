class FileBundle

  class FormatError < Exception; end

  attr_reader :location

  def initialize(options = {})
    @store = options[:store]
    @location = options[:location].chomp('/') if options[:location]
  end

  def save_file(location)
    @location = location.chomp('/')
    @store.put(original_file_path, @file)
  end

  def self.create_from_file(options)
    bundle = new(options)
    bundle.build_from_file(options)
    bundle.save_file(options[:location])
    bundle
  end

  def host
    @store.host
  end

  def protocol
    @store.protocol
  end

  def path
    "#{location}/#{oid}"
  end

  def url
    "#{protocol}#{host}/#{path}"
  end

  def member_url(name)
    "#{url}/#{name}"
  end

  def original_file_name
    "original.#{@format}"
  end

  def original_file_path
    "#{path}/#{original_file_name}"
  end

  def original_file_url
    member_url(original_file_name)
  end

  # The unique name of the file(image or document) used as a folder name in S3 and as an object id in pebbles
  def oid
    @oid ||= "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{@format}-#{SecureRandom.random_number(36**4).to_s(36)}"
  end

  def uid(obj_class)
    "#{obj_class}:#{@location.split('/').join('.')}$#{oid}"
  end

end