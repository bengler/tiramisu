# Usage example
# > file = S3AudioFile.new(Pebblebed::Uid.new('audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording'))
# > file.path_for_version(:sample_rate => 44000, :bitrate => 128000, :format=>'flv')
# => /area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44000_128000.flv

require "lib/s3_file"

class S3AudioFile < S3File
  def dirname
    (uid.path.split(".") << "#{timestamp}-#{random}-#{extension}").join("/")
  end
  def path_for_version(options)
    timestamp, rand, original_extension, *title_slug = uid.oid.split("-")
    parts = [title_slug.join("-")]
    parts << options[:audio_sample_rate] if options[:audio_sample_rate]
    parts << options[:audio_bitrate] if options[:audio_bitrate]
    extension = options[:format]
    "#{dirname}/#{parts.join("_")}.#{extension || original_extension}"
  end
end
