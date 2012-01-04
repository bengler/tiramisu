require 'securerandom'

class ImageBundle

  attr_reader :aspect_ratio, :location

  def initialize(store, uid = nil)
    @store = store
  end

  def build_from_file(file)
    @file = file
    @format, width, height = `identify -format '%m %w %h' #{file.path}`.split(/\s+/)
    @aspect_ratio = width.to_f/height.to_f
    @content = file
  end

  def save_original(location)
    @location = location.chomp('/')
    @store.put(original_image_path, @file)
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

  def original_image_path
    "#{path}/original.#{@format.downcase}"
  end

  def original_image_url
    "#{protocol}#{host}/#{original_image_path}"
  end

  def uid
    "asset:#{@location.split('/').join('.')}$#{oid}"
  end

  # The unique name of the asset used as a folder name in S3 and as an oid in pebbles
  def oid
    @oid ||= "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{(aspect_ratio * 1000).round}-#{SecureRandom.random_number(36**4).to_s(36)}"
  end

  def sizes
    {'100' => "#{url}/100.jpg", '300' => nil, '500' => nil, '1000' => nil, '5000' => nil}
  end

  def self.build_from_file(options, &block)
    bundle = new(options[:store])
    if block_given?
      file = Interceptor.wrap(options[:file]) do |file, method, args|
        block.call(file.pos.to_f/file.size)
      end
    else
      file = options[:file]
    end
    bundle.build_from_file(file)
    bundle.save_original(options[:location])
    bundle
  end

end
