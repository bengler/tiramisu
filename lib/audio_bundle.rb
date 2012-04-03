# Represents a collection of versions of the same audio file.

class AudioBundle

  # Transcode source to these content types
  OUTPUT_FORMATS = [
    {
      :audio_sample_rate => 44100,
      :audio_bitrate => 64000,
      :audio_codec => 'libmp3lame',
      :format => 'mp3',
      :content_type => 'audio/mpeg',
    },
    {
      :audio_sample_rate => 44100,
      :audio_bitrate => 64000,
      :format => "flv",
      :content_type => "video/x-flv"
    }
  ]

  attr_reader :asset_store, :s3_audio_file

  def initialize(asset_store, s3_audio_file)
    #raise FormatError, "Format #{s3_audio_file.extension} not supported" unless SUPPORTED_FORMATS.include?(s3_audio_file.extension)
    @asset_store = asset_store
    @s3_audio_file = s3_audio_file
  end

  def data
    data = {
      :uid => s3_audio_file.uid.to_s,
      :baseurl => asset_store.url_for(s3_audio_file.dirname),
      :original => asset_store.url_for(s3_audio_file.path),
    }
    data[:versions] = OUTPUT_FORMATS.map do |version|
      version.merge(:url => asset_store.url_for(s3_audio_file.path_for_version(version)))
    end
    data
  end

  def tootsie_job
    job = {}
    job[:type] = 'video'
    job[:params] = params = {}
    params[:input_url] = asset_store.url_for(s3_audio_file.path)

    params[:versions] = OUTPUT_FORMATS.map do |format|
      version = {}.merge format
      version[:format] = format[:format]

      target_url = asset_store.s3_url_for(s3_audio_file.path_for_version(format))
      version[:target_url] = "#{target_url}?acl=public_read"
      version
    end
    job
  end
end
