require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  let(:json_chunks) { last_response.body.split("\n").map {|chunk| JSON.parse(chunk)} }
  let(:image_from_fixture) {
    {:file => 'spec/fixtures/ullevaalseter.jpg', :aspect_ratio =>1.499} 
  }
  # [x] Make it pass
  # [ ] Make it right
  # [ ] Make it fast
  describe 'POST /assets/:id' do
    it "submits an image and returns a chunked json response with progress data and finally the image hash" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new(image_from_fixture[:file], "image/jpeg")
      end
      last_response.status.should eq(201)
      chunks = json_chunks

      chunks.first['status'].should eq('received')
      chunks[1]['status'].should eq('transferring')
      chunks.last['status'].should eq('completed')
      chunks.last['percent'].should eq(100)

      image = chunks.last['image']
      image.should_not be_nil

      klass, path, oid = Pebblebed::Uid.parse(image['id']) 
      klass.should eq('image')
      path.should eq('realm.app.collection.box')
      oid.should_not be_nil
      timestamp, aspect_ratio, id = oid.split("-")
      aspect_ratio.to_i.should eq(image_from_fixture[:aspect_ratio]*1000)

      image['baseurl'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}/)
      image['sizes'].map{|s| s['width']}.should eq([100, 100, 300, 500, 700, 1000, 5000])
      
      image['original'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}\/original\.jpeg/)
      image['aspect'].should be_within(0.01).of(1.49)
    end

    it "returns failure as last json hash if uploaded file are of wrong format" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new('spec/fixtures/unsupported-format.xml')
      end
      last_response.status.should eq(201) # yep, because response is streamed headers will already be sent
      chunks = json_chunks
      chunks.last['status'].should eq('failed')
      chunks.last['message'].should eq('format-not-supported')
      chunks.last['percent'].should eq(100)
    end
  end

  it "returns failure as last json hash and includes the error message if something unexpected happens" do
    ImageBundle.any_instance.stub(:generate_sizes).and_raise "Unexpected error"
    VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
      post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new(image_from_fixture[:file], "image/jpeg")
    end
    last_response.status.should eq(201) # yep, because response is streamed headers will already be sent
    chunks = json_chunks
    chunks.last['status'].should eq('failed')
    chunks.last['message'].should eq('Unexpected error')
    chunks.last['percent'].should eq(100)
  end
end
