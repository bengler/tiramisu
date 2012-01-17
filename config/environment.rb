require "bundler"
Bundler.require

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']


# we do not use active record / pg
# we do not use memcached
# we use carrot, but open a new queue for each transaction, I think?
Hupper.on_initialize do
end

Hupper.on_release do
end
