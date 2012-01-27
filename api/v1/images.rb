require 'cgi'
require 'timeout'

class TiramisuV1 < Sinatra::Base

  IMAGE_SIZES = [
    {:width => 100},
    {:width => 100, :square => true},
    {:width => 300},
    {:width => 500, :square => true},
    {:width => 700},
    {:width => 1000},
    {:width => 5000, :medium => 'print'}
  ]

  # POST /images/:uid
  # +file+ multipart post
  # -notification_url-
  # -wait_for_thumbnail- default: false

  post '/images/:id' do |id|
    klass, path, oid = Pebblebed::Uid.parse(id)
    location = path.gsub('.', '/')

    response['X-Accel-Buffering'] = 'no'
    content_type 'application/octet-stream' if request.user_agent =~ /MSIE/

    stream do |out|
      begin
        stream_write_progress out, :percent => 0, :status => 'received'

        # Generate a new image bundle and upload the original image to it
        begin
          bundle = ImageBundle.create_from_file(
            :store => asset_store,
            :file => params[:file][:tempfile],
            :location => location
          ) do |progress| # <- reports progress as a number between 0 and 1 as the original file is uploaded to S3
            stream_write_progress out, :percent => (progress*90).round, :status => 'transferring'
          end
        rescue ImageBundle::FormatError => e
          stream_write_progress out, :percent => 100, :status => 'failed', :message => 'format-not-supported'
          halt 400, 'Format not supported'
        end

        # Submit image scaling job to tootsie
        bundle.generate_sizes(
          :server => settings.config['tootsie'],
          :sizes => IMAGE_SIZES,
          :notification_url => params[:notification_url])

        stream_write_progress out, :percent => 100,
                                    :status => 'completed', # 'cause we're done
                                    :image => {
                                      :id => bundle.uid,
                                      :baseurl => bundle.url,
                                      :sizes => bundle.sizes,
                                      :original => bundle.original_image_url,
                                      :aspect => bundle.aspect_ratio
                                    }
      rescue => e
        out << e
      end
    end
  end

  private
  def stream_write_progress(out, progress)
    out << "#{progress.to_json}\n"
  end
end
