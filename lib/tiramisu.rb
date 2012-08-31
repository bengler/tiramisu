module Tiramisu
  def self.config
    if ENV['RACK_ENV'] == 'test'
      @config ||= {
        "S3" => {
          "access_key_id" => ENV.fetch('TIRAMISU_S3_KEY'),
          "secret_access_key" => ENV.fetch('TIRAMISU_S3_SECRET_KEY'),
          "bucket" => ENV.fetch('TIRAMISU_S3_BUCKET')
        },
        "tootsie"=>"http://localhost:9000"
      }
    else
      @config ||= YAML::load(File.open("config/services.yml"))[ENV['RACK_ENV']]
    end
  end
end
