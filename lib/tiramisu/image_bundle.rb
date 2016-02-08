# Represents a collection of versions of the same image. Typically an original
# upload + scaled and cleaned versions of that image.

class ImageBundle

  PREFERRED_SIZES = [
    {:width => 100},
    {:width => 100, :square => true},
    {:width => 300},
    {:width => 500, :square => true},
    {:width => 700},
    {:width => 1000},
    {:width => 1600},
    {:width => 2048},
    {:width => 3000},
    {:width => 5000, :medium => 'print'}
  ]

  # Maps from imagemagic format output to the extension used in urls
  EXTENSIONS = {
    'jpg' => 'jpg',
    'jpeg' => 'jpg',
    'gif' => 'gif',
    'png' => 'png'
  }

  attr_reader :asset_store, :s3_image_file

  def initialize(asset_store, s3_image_file, options)
    @asset_store = asset_store
    @s3_image_file = s3_image_file
    @options = options
  end

  def metadata
    {
      :uid => s3_image_file.uid.to_s,
      :baseurl => asset_store.url_for(s3_image_file.dirname),
      :original => asset_store.url_for(s3_image_file.path),
      :fullsize => versions.last[:url],
      :aspect_ratio => s3_image_file.aspect_ratio.to_f/1000.0,
      :versions => versions
    }
  end

  def fullsize
    {
      width: @options[:width],
      square: (1.0 - @options[:aspect_ratio]).abs < 0.01
    }
  end

  def valid_sizes
    PREFERRED_SIZES
      .select { |size|
        size[:width] <= @options[:width]
      }
      .map { |size|
        {:width => size[:width], :square => !!size[:square]}
      }
      .push(fullsize) # Append original dimensions too
  end

  def target_format
    @target_format ||= @options[:format] || 'jpeg'
  end

  def versions
    valid_sizes
      .map { |size|
        s3_path = s3_image_file.path_for_size(size[:width],
          :square => size[:square],
          :extension => EXTENSIONS[target_format]
        )
        s3_url = asset_store.url_for(s3_path)
        {
          width: size[:width],
          square: size[:square],
          url: s3_url
        }
      }
  end

  def to_tootsie_job
    params = {}
    params[:input_url] = asset_store.url_for(s3_image_file.path)
    params[:versions] = valid_sizes.map do |size|
      version = {}
      if size[:square]
        version[:scale] = 'fit'
        version[:height] = size[:width]
        version[:crop] = true
      end
      version[:format] = target_format
      version[:width] = size[:width]
      version[:strip_metatadata] = true
      version[:medium] = 'web'
      path_for_size = s3_image_file.path_for_size(size[:width],
        :square => size[:square],
        :extension => EXTENSIONS[target_format]
      )
      target_url = asset_store.s3_url_for(path_for_size)
      version[:target_url] = "#{target_url}?acl=public_read"
      version
    end

    {
      type: 'image',
      params: params
    }
  end

end
