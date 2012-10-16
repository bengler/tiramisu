require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  describe 'POST /files/:uid' do

    let(:chunked_json_response) { last_response.body.split("\n").map { |chunk| JSON.parse(chunk) } }
    let(:file_from_fixture) {
      'spec/fixtures/programmer.pdf'
    }

    it "submits a file returns a chunked json response with progress data and finally the file object" do

      AssetStore.any_instance.should_receive(:put).once do |url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/files/file:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(file_from_fixture, "application/pdf")
      end
      last_response.status.should eq(200)
      chunks = chunked_json_response

      chunks.first['status'].should eq('received')
      chunks[1]['status'].should eq('transferring')
      chunks.last['status'].should eq('completed')
      chunks.last['percent'].should eq(100)

      file = chunks.last['metadata']
      file.should_not be_nil

      klass, path, oid = Pebbles::Uid.parse(file['uid'])
      klass.should eq('file')
      path.should eq('realm.app.collection.box')
      oid.should_not be_nil

      file['baseurl'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/.*/)

      file['original'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/.*\/programmer\.pdf/)

    end

    it "returns failure as last json hash and includes the error message if something unexpected happens" do
      AssetStore.any_instance.should_receive(:put).once.and_raise("Funky error") # just to make something fail

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/files/file:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(file_from_fixture, "image/pdf")
      end

      last_response.status.should eq(200)
      chunks = chunked_json_response
      chunks.last['status'].should eq('failed')
      chunks.last['message'].should eq('Funky error')
      chunks.last['percent'].should eq(100)
    end
  end

end
