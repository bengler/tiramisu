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

  attr_reader :aspect_ratio

  def initialize(options = {})
    super(options)
    @aspect_ratio = options[:aspect_ratio]
  end

  def build_from_file(options)
    @file = options[:file]
    @format, width, height = `identify -format '%m %w %h' #{@file.path}`.split(/\s+/)
    @format.downcase! if @format
    raise FormatError, "Format #{@format.inspect} not supported" unless SUPPORTED_FORMATS.include?(@format)
    @aspect_ratio = width.to_f/height.to_f
  end

  def has_member?(name)
    client = HTTPClient.new
    response = client.head(member_url(name))
    ((200...300).include?(response.status_code))
  end

  def has_size?(size)
    has_member?("#{size[:width]}#{size[:square] ? 'sq' : ''}.jpg")
  end

  # :server - tootsie server
  # :sizes - array of sizes [{:width => integer, :square => boolean}, ...]
  # :notification_url - url tootsie will notify when the job is done
  def submit_image_scaling_job(options)
    TootsieHelper.generate_sizes(options[:server],
                                 :source => original_file_url,
                                 :bucket => @store.bucket.name,
                                 :path => path,
                                 :sizes => IMAGE_SIZES,
                                 :notification_url => options[:notification_url]
    )
  end

  def sizes
    IMAGE_SIZES.map do |image|
      {
          :width => image[:width],
          :square => !!(image[:square]),
          :url => "#{url}/#{image[:width]}#{image[:square] ? 'sq' : ''}.jpg"
      }
    end
  end

  def image_data
    {
        :id => uid("image"),
        :baseurl => url,
        :sizes => sizes,
        :original => original_file_url,
        :aspect => aspect_ratio
    }
  end
end
