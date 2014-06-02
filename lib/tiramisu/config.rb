module Tiramisu
  class Config

    CONFIG_FILE_PATH = "config/services.yml"
  
    attr_reader :environment

    def initialize(environment)
      @environment = environment
    end

    def settings
      @settings ||= config_exists? ? config : ci_config
    end

    private

    def config
      YAML::load(File.open(CONFIG_FILE_PATH))[environment]
    end

    def config_exists?
      File.exists?(CONFIG_FILE_PATH)
    end

    # Allows secrets to be stored in environment so that
    # they do not need to be committed to local repositories.
    # This makes it possible to run on the CI server.
    def ci_config
      {
        "S3" => {
          "access_key_id" => ENV.fetch('TIRAMISU_S3_KEY'),
          "secret_access_key" => ENV.fetch('TIRAMISU_S3_SECRET_KEY'),
          "bucket" => ENV.fetch('TIRAMISU_S3_BUCKET')
        },
        "tootsie"=>"localhost"
      }
    end

  end
end

