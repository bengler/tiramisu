require 'securerandom'
require './lib/file_bundle'

class DocumentBundle < FileBundle

  def build_from_file(options = {})
    @file = options[:file]
    @format = options[:format]
  end

  def document_data
    {
        :id => uid("document"),
        :baseurl => url,
        :original => original_file_url
    }
  end

end
