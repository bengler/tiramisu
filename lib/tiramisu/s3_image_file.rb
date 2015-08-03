# Represents a file stored in s3 with Uid as part of the url
# Only difference from S3File is that it requires the :aspect_ratio parameter to be given, and includes this in the oid
# Thus, the oid is structured like this: `[timestamp]-[random_string]-[filename]-[aspect_ratio]`.
#
# Note that the aspect ratio is multiplied by 1000
#
# I.e. the following Uid:
#
#                  Timestamp v------------v v--v--- Aspect ratio (1.498)
#   image:area51.secret.unit$20120306122011-1498-9et0
#                               Random string ---^--^
#
# Translates into the following s3 file path:
# area51/secret/unit/20120306122011-1489-9et0/original.jpg
#
# Examples:
#   > file = S3ImageFile.new(Pebbles::Uid.new('image:area51.secret.unit$20120306122011-1498-9et0'))
#   > file.path
#   => "area51/secret/unit/20120306122011-1498-9et0/original.jpg"
#   > file.dirname
#   => "area51/secret/unit/20120306122011-1498-9et0"
#
# It will also help figuring out the path of different sizes of the image, i.e.
#
#   > file = S3ImageFile.new(Pebbles::Uid.new('image:area51.secret.unit$20120306122011-1498-9et0'))
#   > file.path_for_size(100)
#   => "area51/secret/unit/20120306122011-1498-9et0/100.jpg"
#
#   > file.path_for_size(100, :square => true)
#   => "area51/secret/unit/20120306122011-1498-9et0/100sq.jpg"

require "tiramisu/s3_file"

class S3ImageFile < S3File

  def self.create_oid(options)
    timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
    rnd = SecureRandom.random_number(36**4).to_s(36)
    "#{timestamp}-#{(options[:aspect_ratio] * 1000).round}-#{rnd}"
  end

  def dirname
    (uid.path.split(".") << "#{timestamp}-#{aspect_ratio}-#{random}").join("/")
  end

  # Full path of file (including filename)
  def path
    path_for_size('original', extension: original_extension)
  end

  def basename
    'original'
  end

  def aspect_ratio
    parse.last
  end

  def path_for_size(size, options = {})
    sq = options[:square] ? 'sq' : ''
    ext = options[:extension] || extension
    "#{dirname}/#{size}#{sq}.#{ext}"
  end

  def parse
    timestamp, aspect_ratio, rand = uid.oid.split("-")
    [timestamp, rand, 'jpg', 'original', aspect_ratio]
  end
end
