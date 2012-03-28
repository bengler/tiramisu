require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  let(:json_chunks) { last_response.body.split("\n").map {|chunk| JSON.parse(chunk)} }
  let(:file_from_fixture) {
    {:file => 'spec/fixtures/forester.pdf', :aspect_ratio =>1.499} 
  }
  describe 'POST /assets/:id' do
    it "submits an image and returns a chunked json response with progress data and finally the image hash" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/documents/document:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new(file_from_fixture[:file], "application/pdf")
      end
      last_response.status.should eq(200)
      chunks = json_chunks

      chunks.first['status'].should eq('received')
      chunks[1]['status'].should eq('transferring')
      chunks.last['status'].should eq('completed')
      chunks.last['percent'].should eq(100)

      document = chunks.last['document']
      document.should_not be_nil

      klass, path, oid = Pebblebed::Uid.parse(document['id']) 
      klass.should eq('document')
      path.should eq('realm.app.collection.box')
      oid.should_not be_nil

      document['baseurl'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}/)
      
      document['original'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}\/original\.pdf/)

    end

  end

  it "returns failure as last json hash and includes the error message if something unexpected happens" do
    DocumentBundle.stub(:create_from_file).and_raise "Funky error"
    VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
      post "/documents/document:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new(file_from_fixture[:file], "image/pdf")
    end
    last_response.status.should eq(200)
    chunks = json_chunks
    chunks.last['status'].should eq('failed')
    chunks.last['message'].should eq('Funky error')
    chunks.last['percent'].should eq(100)
  end
end
