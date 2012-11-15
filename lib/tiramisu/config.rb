module Tiramisu
  class Config

    attr_reader :environment
    def initialize(environment)
      @environment = environment
    end

    def settings
      @settings ||= test? ? test_config : config
    end

    def test?
      environment == 'test'
    end

    private

    def config
      YAML::load(File.open("config/services.yml"))[environment]
    end

    # Allows secrets to be stored in environment so that
    # they do not need to be committed to local repositories.
    # This makes it possible to run on the CI server.
    def test_config
      {
        "S3" => {
          "access_key_id" => ENV.fetch('TIRAMISU_S3_KEY'),
          "secret_access_key" => ENV.fetch('TIRAMISU_S3_SECRET_KEY'),
          "bucket" => ENV.fetch('TIRAMISU_S3_BUCKET')
        },
        "tootsie"=>"http://localhost:9000"
      }
    end

  end
end

