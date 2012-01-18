$:.unshift(File.dirname(__FILE__))

begin
  require 'bengler_test_helper/tasks'
rescue LoadError => e
  puts e.message
end

task :environment do
  require 'config/environment'
end
