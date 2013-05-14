require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  describe 'POST /images/:uid' do

    let(:chunked_json_response) { last_response.body.split("\n").map { |chunk| JSON.parse(chunk) } }
    let(:image_from_fixture) {
      {:file => 'spec/fixtures/ullevaalseter.jpg', :aspect_ratio => 1.499}
    }

    it "submits an image and returns a chunked json response with progress data and finally the image hash" do

      AssetStore.any_instance.should_receive(:put).once do |url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      Pebblebed::GenericClient.any_instance.should_receive(:post).with("/jobs", anything()).once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$", :file => Rack::Test::UploadedFile.new(image_from_fixture[:file], "image/jpeg")
      end

      last_response.status.should eq(200)
      chunks = chunked_json_response

      chunks.first['status'].should eq('received')
      chunks[1]['status'].should eq('transferring')
      chunks.last['status'].should eq('completed')
      chunks.last['percent'].should eq(100)

      image = chunks.last['metadata']
      image.should_not be_nil

      klass, path, oid = Pebbles::Uid.parse(image['uid'])
      klass.should eq('image')
      path.should eq('realm.app.collection.box')
      oid.should_not be_nil

      timestamp, aspect_ratio, rand= oid.split("-")
      aspect_ratio.to_i.should eq(image_from_fixture[:aspect_ratio]*1000)

      image['baseurl'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{timestamp}-#{aspect_ratio}-#{rand}/)
      image['versions'].map { |s| s['width'] }.should eq([100, 100, 300, 500, 700, 1000, 5000])

      image['original'].should match(/#{image['baseurl']}\/original.jpg/)
      image['aspect_ratio'].to_f.should be_within(0.01).of(1.49)
    end

    it "returns failure as last json chunk if uploaded file are of wrong format" do

      AssetStore.any_instance.should_not_receive(:put)
      
      Pebblebed::Connector.any_instance.should_not_receive(:post)

      post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new('spec/fixtures/unsupported-format.xml')

      last_response.status.should eq(200)
      chunks = chunked_json_response
      chunks.last['status'].should eq('failed')
      chunks.last['message'].should eq('format-not-supported')
      chunks.last['percent'].should eq(100)
    end

    it "returns failure as last json chunk and includes the error message if something unexpected happens" do
      AssetStore.any_instance.should_receive(:put).once.and_raise("Unexpected error") # just to make something fail

      Pebblebed::Connector.any_instance.should_not_receive(:post)

      post "/images/image:realm.app.collection.box$", :file => Rack::Test::UploadedFile.new(image_from_fixture[:file], "image/jpeg")

      last_response.status.should eq(200)
      chunks = chunked_json_response
      chunks.last['status'].should eq('failed')
      chunks.last['message'].should eq('Unexpected error')
      chunks.last['percent'].should eq(100)
    end
  end
end
