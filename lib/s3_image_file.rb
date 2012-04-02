# Represents a file stored in s3 with Uid as part of the url
# Only difference from S3File is that it requires the :aspect_ratio parameter to be given, and includes this in the oid
# Thus, the oid is structured like this: `[timestamp]-[random_string]-[filename]-[aspect_ratio]`.
#
# Note that the aspect ratio is multiplied by 1000
# 
# I.e. the following Uid:
#
#                  Timestamp v------------v      v-v--- Extension       v--v--- Aspect ratio (1.498)
#   image:area51.secret.unit$20120306122011-9et0-jpg-super-secret-photo-1498
#                          Random string ---^--^     ^--- Filename ---^      
#
# Translates into the following s3 file path:
# /area51/secret/unit/20120306122011-9et0-jpg-super-secret-photo-1489/super-secret-photo.jpg
#
# Examples:
#   > file = S3ImageFile.new(Pebblebed::Uid.new('image:area51.secret.unit$20120306122011-9et0-jpg-super-secret-photo-1498'))
#   > file.path
#   => "area51/secret/unit/20120306122011-9et0-1498/super-secret-photo.jpg"
#   > file.dirname
#   => "area51/secret/unit/20120306122011-9et0-1498"
#
# It will also help figuring out the path of different sizes of the image, i.e.
#
#   > file = S3ImageFile.new(Pebblebed::Uid.new('image:area51.secret.unit$20120306122011-9et0-jpg-super-secret-photo-1498'))
#   > file.path_for_size(100)
#   => "area51/secret/unit/20120306122011-9et0-1498/super-secret-photo_100.jpg"
#
#   > file.path_for_size(100, :square => true)
#   => "area51/secret/unit/20120306122011-9et0-1498/super-secret-photo_100_sq.jpg"

class S3ImageFile < S3File

  def self.create_oid(options)
    oid = super(options)
    "#{oid}-#{(options[:aspect_ratio] * 1000).round}"
  end

  def dirname
    (uid.path.split(".") << "#{timestamp}-#{random}-#{aspect_ratio}").join("/")
  end

  def aspect_ratio
    parse.last
  end

  def path_for_size(size, options = {})
    parts = [basename, size]
    parts << "sq" if options[:square]
    ext = options[:format] || extension 
    "#{dirname}/#{parts.join("_")}.#{ext}"
  end

  def parse
    timestamp, rand, extension, *filename, aspect_ratio = uid.oid.split("-")
    [timestamp, rand, extension, filename.join("-"), aspect_ratio]
  end
end
