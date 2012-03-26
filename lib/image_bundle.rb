# Represents a collection of versions of the same image. Typically an original 
# upload + scaled and cleaned versions of that image.

require 'securerandom'
require './lib/file_bundle'

class ImageBundle < FileBundle

  SUPPORTED_FORMATS = ['png', 'jpeg', 'bmp', 'gif', 'tiff', 'gif', 'pdf', 'psd']

  IMAGE_SIZES = [
    {:width => 100},
    {:width => 100, :square => true},
    {:width => 300},
    {:width => 500, :square => true},
    {:width => 700},
    {:width => 1000},
    {:width => 5000, :medium => 'print'}
  ]

  class FormatError < Exception; end

  attr_reader :aspect_ratio, :location

  def initialize(store, options = {})
    @store = store
    @location = options[:location].chomp('/') if options[:location]
    @aspect_ratio = options[:aspect_ratio]
  end

  def build_from_file(file)
    @file = file
    @format, width, height = `identify -format '%m %w %h' #{file.path}`.split(/\s+/)
    @format.downcase! if @format
    raise FormatError, "Format #{@format.inspect} not supported" unless SUPPORTED_FORMATS.include?(@format)
    @aspect_ratio = width.to_f/height.to_f
    @content = file
  end

  def save_original(location)
    @location = location.chomp('/')
    @store.put(original_image_path, @file)
  end

  def has_member?(name)
    client = HTTPClient.new
    response = client.head(member_url(name))
    return ((200...300).include?(response.status_code))
  end

  def has_size?(size)
    has_member?("#{size[:width]}#{size[:square] ? 'sq' : ''}.jpg")
  end

  def self.create_from_file(options)
    bundle = new(options[:store])
    bundle.build_from_file(options[:file])
    bundle.save_original(options[:location])
    bundle
  end

  # :server - tootsie server
  # :sizes - array of sizes [{:width => integer, :square => boolean}, ...]
  # :notification_url - url tootsie will notify when the job is done
  def submit_image_scaling_job(options)
    TootsieHelper.generate_sizes(options[:server],
      :source => original_image_url,
      :bucket => @store.bucket.name,
      :path => path,
      :sizes => IMAGE_SIZES,
      :notification_url => options[:notification_url]
    )
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

  def original_image_name
    "original.#{@format}"
  end

  def original_image_path
    "#{path}/#{original_image_name}"
  end

  def original_image_url
    member_url(original_image_name)
  end

  def uid
    "image:#{@location.split('/').join('.')}$#{oid}"
  end

  # The unique name of the image used as a folder name in S3 and as an object id in pebbles
  def oid
    @oid ||= "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{(aspect_ratio * 1000).round}-#{SecureRandom.random_number(36**4).to_s(36)}"
  end

  def sizes
    IMAGE_SIZES.map do |image|
      {:width => image[:width], :square => !!(image[:square]), :url => "#{url}/#{image[:width]}#{image[:square] ? 'sq' : ''}.jpg"}
    end
  end

  def image_data
    {
      :id => uid,
      :baseurl => url,
      :sizes => sizes,
      :original => original_image_url,
      :aspect => aspect_ratio
    }
  end
end
