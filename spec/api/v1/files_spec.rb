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

      expect_any_instance_of(AssetStore).to receive(:put).once do |instance, url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/files/file:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(file_from_fixture, "application/pdf")
      end
      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      expect(chunks.first['status']).to eq('received')
      expect(chunks[1]['status']).to eq('transferring')
      expect(chunks.last['status']).to eq('completed')
      expect(chunks.last['percent']).to eq(100)

      file = chunks.last['metadata']
      expect(file).to_not be_nil

      klass, path, oid = Pebbles::Uid.parse(file['uid'])
      expect(klass).to eq('file')
      expect(path).to eq('realm.app.collection.box')
      expect(oid).to_not be_nil

      expect(file['baseurl']).to match(/http\:\/\/.+\/#{path.split(".").join("/")}\/.*/)

      expect(file['original']).to match(/http\:\/\/.+\/#{path.split(".").join("/")}\/.*\/programmer\.pdf/)

    end

    it "returns failure as last json hash and includes the error message if something unexpected happens" do
      expect_any_instance_of(AssetStore).to receive(:put).once.and_raise("Funky error") # just to make something fail

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/files/file:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(file_from_fixture, "image/pdf")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response
      expect(chunks.last['status']).to eq('failed')
      expect(chunks.last['message']).to eq('Funky error')
      expect(chunks.last['percent']).to eq(100)
    end
  end

end
