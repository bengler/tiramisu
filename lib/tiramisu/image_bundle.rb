# Represents a collection of versions of the same image. Typically an original
# upload + scaled and cleaned versions of that image.

class ImageBundle

  OUTPUT_FORMAT = 'jpg'

  IMAGE_SIZES = [
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

  attr_reader :asset_store, :s3_image_file

  def initialize(asset_store, s3_image_file)
    @asset_store = asset_store
    @s3_image_file = s3_image_file
  end

  def metadata
    metadata = {
      :uid => s3_image_file.uid.to_s,
      :baseurl => asset_store.url_for(s3_image_file.dirname),
      :original => asset_store.url_for(s3_image_file.path),
      :aspect_ratio => s3_image_file.aspect_ratio.to_f/1000.0
    }
    metadata[:versions] = IMAGE_SIZES.map do |size|
      square = !!size[:square]
      s3_path = s3_image_file.path_for_size(size[:width], :square => size[:square], :format => OUTPUT_FORMAT)
      s3_url = asset_store.url_for(s3_path)

      {:width => size[:width], :square => square, :url => s3_url }
    end
    metadata
  end

  def to_tootsie_job
    job = {}
    job[:type] = 'image'
    job[:params] = params = {}
    params[:input_url] = asset_store.url_for(s3_image_file.path)
    params[:versions] = IMAGE_SIZES.map do |size|
      version = {}
      if size[:square]
        version[:scale] = 'fit'
        version[:height] = size[:width]
        version[:crop] = true
      end
      version[:format] = "jpeg"
      version[:width] = size[:width]
      version[:strip_metatadata] = true
      version[:medium] = size[:medium] || 'web'
      path_for_size = s3_image_file.path_for_size(size[:width], :square => size[:square], :format => OUTPUT_FORMAT)
      target_url = asset_store.s3_url_for(path_for_size)
      version[:target_url] = "#{target_url}?acl=public_read"
      version
    end
    job
  end
end
