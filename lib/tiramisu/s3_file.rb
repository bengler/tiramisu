# Represents a file stored in s3 at a location derived from its uid
#
# I.e. the following Uid:
#
#                       Timestamp -----v------------v      v-v--- Extension
#   file:agricult.forestry101.spring12$20120329234410-7yv6-pdf-the-training-of-a-forester-by-gifford-pinchot
#                                    Random string ---^--^     ^--- Filename ------------------------------^
#
# ... the file path on S3 will be:
#   agricult/forestry101/spring12/20120329234410-7yv6/the-training-of-a-forester-by-gifford-pinchot.pdf
#
#   Examples:
#
# > uid = Pebbles::Uid.new "agricult/forestry101/spring12/20120329234410-7yv6/the-training-of-a-forester-by-gifford-pinchot.pdf"
# > s3file = S3File.new(uid)
# > s3file.path
# => "agricult/forestry101/spring12/20120329234410-7yv6/the-training-of-a-forester-by-gifford-pinchot.pdf"
# > s3file.dirname
# => "agricult/forestry101/spring12/20120329234410-7yv6"
# > s3file.extension
# => "pdf"
#
# Note: This class should be kept asset store agnostic and just be concerned with
#       encoding/decoding file info from an Uid

class S3File

  class IncompleteUidError < Exception;  end

  def self.create(base_uid, options)
    genus, path, _ = Pebbles::Uid.parse(base_uid.to_s)
    oid = create_oid(options)
    uid = Pebbles::Uid.new(Pebbles::Uid.build(genus, path, oid))
    new(uid, options)
  end

  # Generates an unique oid based on a set of options.
  #
  # @param [options] The options hash. Valid options are:
  #   :filename => Name of file (defaults to `original`)
  #   :extension => File extension (defaults to File.extname of options[:filename])
  #   Note that it is a bad idea to provide neither :filename or :extension
  # @return [String] the oid

  def self.create_oid(options)
    filename = options[:filename]
    extension = File.extname(filename)
    basename = File.basename(filename, extension)

    extension = options[:extension] if options[:extension] # override extension if given

    timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
    filename = basename.parameterize("-")
    random = SecureRandom.random_number(36**4).to_s(36)
    [timestamp, random, extension.sub(/^\./, '').downcase, filename].join("-")
  end

  attr_reader :uid

  # Uid must be instance of Pebbles::Uid
  def initialize(uid, options={})
    raise IncompleteUidError, "Missing oid in uid" if uid.oid.nil?
    @uid = uid
    @options = options
  end

  # Path of the directory where file is located
  # Equivalent of File.dirname(s3file.path)
  def dirname
    (uid.path.split(".") << "#{timestamp}-#{random}").join("/")
  end

  # Full path of file (including filename)
  def path
    "%s/%s" % [dirname, filename]
  end

  def filename
    "%s.%s" % [basename, extension]
  end

  def timestamp
    parse[0]
  end

  def random
    parse[1]
  end

  def extension
    parse[2]
  end

  def original_extension
    @options[:original_extension]
  end

  def basename
    parse[3]
  end

  protected

  def parse
    timestamp, random, extension, *filename = @uid.oid.split("-")
    [timestamp, random, extension, filename.join("-")]
    end
end
