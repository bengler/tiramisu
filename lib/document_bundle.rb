require 'securerandom'

class DocumentBundle

  SUPPORTED_FORMATS = ['doc', 'docx', 'xls', 'xlsx', 'djvu', 'pdf', 'mp3']

  class FormatError < Exception; end

  attr_reader :location

  def initialize(store, options = {})
    @store = store
    @location = options[:location].chomp('/') if options[:location]
  end

  def build_from_file(file, format)
    @file = file
    @format = format
    @format.downcase! if @format
    raise FormatError, "Format #{@format.inspect} not supported" unless SUPPORTED_FORMATS.include?(@format)
    @content = file
  end

  def save(location)
    @location = location.chomp('/')
    @store.put(document_path, @file)
  end

  def self.create_from_file(options, &block)
    bundle = new(options[:store])
    bundle.build_from_file(options[:file], options[:format])
    bundle.save(options[:location])
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

  def document_name
    "original.#{@format}"
  end

  def document_path
    "#{path}/#{document_name}"
  end

  def document_url
    member_url(document_name)
  end

  def uid
    "document:#{@location.split('/').join('.')}$#{oid}"
  end

  # The unique name of the image used as a folder name in S3 and as an object id in pebbles
  def oid
    @oid ||= "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{@format}-#{SecureRandom.random_number(36**4).to_s(36)}"
  end

  def document_data
    {
        :id => uid,
        :baseurl => url,
        :original => document_url
    }
  end

end