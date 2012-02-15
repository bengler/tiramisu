require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  let(:json_chunks) { last_response.body.split("\n").map { |chunk| JSON.parse(chunk) } }

  let(:file_from_fixture) { {
      :image => {:file => 'spec/fixtures/ullevaalseter.jpg', :aspect_ratio => 1.499},
      :document => {:file => 'spec/fixtures/0dd75f899b4e.mp3'}
  } }

  # [x] Make it pass
  # [ ] Make it right
  # [ ] Make it fast
  describe 'POST /assets/:id' do
    it "submits an image and returns a chunked json response with progress data and finally the image hash" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new(file_from_fixture[:image][:file], "image/jpeg")
      end
      last_response.status.should eq(200)
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
      timestamp, format, id = oid.split("-")
      format.should eq("jpeg")

      image['baseurl'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}/)
      image['sizes'].map { |s| s['width'] }.should eq([100, 100, 300, 500, 700, 1000, 5000])

      image['original'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}\/original\.jpeg/)
      image['aspect'].should be_within(0.01).of(1.49)
    end

    it "submits a document and returns a chunked json response with progress data and finally the document hash" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/documents/document:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new(file_from_fixture[:document][:file], "audio/mpeg3")
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

      timestamp, format, hash = oid.split("-")
      format.should eq(file_from_fixture[:document][:file].split(/\./).last)

      document['baseurl'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}/)
      document['original'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{oid}\/original\.mp3/)
    end

    it "returns failure as last json hash if uploaded file are of wrong format" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new('spec/fixtures/unsupported-format.xml')
      end
      last_response.status.should eq(200)
      chunks = json_chunks
      chunks.last['status'].should eq('failed')
      chunks.last['message'].should eq('format-not-supported')
      chunks.last['percent'].should eq(100)
    end
  end

  it "returns failure as last json hash and includes the error message if something unexpected happens" do
    ImageBundle.any_instance.stub(:submit_image_scaling_job).and_raise "Unexpected error"
    VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
      post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new(file_from_fixture[:image][:file], "image/jpeg")
    end
    last_response.status.should eq(200)
    chunks = json_chunks
    chunks.last['status'].should eq('failed')
    chunks.last['message'].should eq('Unexpected error')
    chunks.last['percent'].should eq(100)
  end
end
