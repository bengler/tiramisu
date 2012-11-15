Dir.glob('./lib/tiramisu/**/*.rb').each { |lib| require lib }

module Tiramisu

  def self.config
    @config ||= Config.new(environment).settings
  end

  def self.environment
    ENV['RACK_ENV'] ||= 'development'
  end

end

