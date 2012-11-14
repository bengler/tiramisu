Dir.glob('./lib/tiramisu/**/*.rb').each { |lib| require lib }

module Tiramisu
  def self.config
    @config ||= test_config if test?
    @config ||= service_config
  end

  def self.environment
    ENV['RACK_ENV'] ||= 'development'
  end

  def self.test?
    environment == 'test'
  end

  private

  def self.test_config
    {
      "S3" => {
        "access_key_id" => ENV.fetch('TIRAMISU_S3_KEY'),
        "secret_access_key" => ENV.fetch('TIRAMISU_S3_SECRET_KEY'),
        "bucket" => ENV.fetch('TIRAMISU_S3_BUCKET')
      },
      "tootsie"=>"http://localhost:9000"
    }
  end

  def self.service_config
    YAML::load(File.open("config/services.yml"))[environment]
  end
end

