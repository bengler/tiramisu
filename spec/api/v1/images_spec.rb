require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  describe 'DELETE /images' do

    it 'only gods may delete stuff' do
      delete '/images', :path => 'realm/app/collection/bliff/300.jpg'
      expect(last_response.status).to eq(403)
    end

    it 'works' do
      path = 'realm/app/collection/bliff/300.jpg'
      expect_any_instance_of(TiramisuV1).to receive(:identity_is_god?).once.and_return true
      expect_any_instance_of(AssetStore).to receive(:delete).once.with(path).and_return true

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        delete '/images', :path => path
      end

      expect(last_response.status).to eq(200)
      success = JSON.parse(last_response.body)['deleted']
      expect(success).to be true
    end

    it 'works with bucket prefix to path' do
      path = 'apps.o5.no/realm/app/collection/bliff/300.jpg'
      stripped_path = path.sub(/^\w+\.o5\.no\//, '')
      expect_any_instance_of(TiramisuV1).to receive(:identity_is_god?).once.and_return true
      expect_any_instance_of(AssetStore).to receive(:delete).once.with(stripped_path).and_return true

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        delete '/images', :path => path
      end

      expect(last_response.status).to eq(200)
      success = JSON.parse(last_response.body)['deleted']
      expect(success).to be true
    end

  end

  describe 'POST /images/:uid' do

    let(:chunked_json_response) { last_response.body.split("\n").map { |chunk| JSON.parse(chunk) } }
    let(:uploaded_image) {
      'spec/fixtures/ullevaalseter.jpg' # width: 640px
    }
    let(:rotated_image) {
      'spec/fixtures/rotated.jpg'
    }
    let(:iphone_portrait) {
      'spec/fixtures/iphone_portrait.jpg'
    }
    let(:wrongly_rotated_image) {
      'spec/fixtures/wrong-orientation.jpg'
    }
    let(:gif_image) {
      'spec/fixtures/pandafail.gif'
    }
    let(:bmp_image) {
      'spec/fixtures/mann.bmp'
    }

    it "submits an image and returns a chunked json response with progress data and finally the image hash" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |instance, url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post).with("/jobs", anything()).once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$", :file => Rack::Test::UploadedFile.new(uploaded_image, "image/jpeg")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      expect(chunks.first['status']).to eq('received')
      expect(chunks[1]['status']).to eq('transferring')
      expect(chunks.last['status']).to eq('completed')
      expect(chunks.last['percent']).to eq(100)

      image = chunks.last['metadata']
      expect(image).to_not be_nil

      klass, path, oid = Pebbles::Uid.parse(image['uid'])
      expect(klass).to eq('image')
      expect(path).to eq('realm.app.collection.box')
      expect(oid).to_not be_nil

      timestamp, aspect_ratio, rand = oid.split("-")
      expect(aspect_ratio.to_i).to eq 1499

      expect(image['baseurl']).to match(/https\:\/\/.+\/#{path.split(".").join("/")}\/#{timestamp}-#{aspect_ratio}-#{rand}/)
      expect(image['versions'].map { |s| s['width'] }).to eq([100, 100, 300, 500, 640])

      expect(image['original']).to match(/#{image['baseurl']}\/original.jpg/)
      expect(image['aspect_ratio'].to_f).to be_within(0.001).of(1.499)
    end

    it "calculates correct aspect ratio for rotated images" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |instance, url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post).with("/jobs", anything()).once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$", :file => Rack::Test::UploadedFile.new(rotated_image, "image/jpeg")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      image = chunks.last['metadata']
      expect(image).to_not be_nil
      oid = Pebbles::Uid.parse(image['uid']).last
      expect(oid).to_not be_nil

      _, aspect_ratio, _ = oid.split("-")

      expect(aspect_ratio.to_i).to eq 1333

      expect(image['aspect_ratio'].to_f).to be_within(0.001).of(1.333)
    end


    it "calculates correct aspect ratio for iphone portrait image" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |instance, url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post).with("/jobs", anything()).once

      file_to_upload = Rack::Test::UploadedFile.new(iphone_portrait, "image/jpeg")
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$", :file => file_to_upload
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      image = chunks.last['metadata']
      expect(image).to_not be_nil
      oid = Pebbles::Uid.parse(image['uid']).last
      _, aspect_ratio, _ = oid.split("-")
      expect(oid).to_not be_nil
      expect(aspect_ratio.to_i).to eq 750
      expect(image['aspect_ratio'].to_f).to be_within(0.001).of(0.75)
    end


    it "forces an orientation on image" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |instance, url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post).with("/jobs", anything()).once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$?force_orientation=left-bottom", {
          :file => Rack::Test::UploadedFile.new(wrongly_rotated_image, "image/jpeg")
        }
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      image = chunks.last['metadata']
      expect(image).to_not be_nil
      oid = Pebbles::Uid.parse(image['uid']).last
      expect(oid).to_not be_nil

      _, aspect_ratio, _ = oid.split("-")

      expect(aspect_ratio.to_i).to eq 1333

      expect(image['aspect_ratio'].to_f).to be_within(0.001).of(1.333)
    end

    it "converts to jpeg unless explicitly told not to" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |_, _, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post) {|_, endpoint, params|
        expect(endpoint).to eq('/jobs')
        expect(params[:params][:input_url]).to end_with("original.gif")

        versions = params[:params][:versions]

        versions.each do |version|
        expect(version[:target_url]).to match(/\d+(sq)?\.jpg\?.*$/)
        end
      }.once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$", :file => Rack::Test::UploadedFile.new(gif_image, "image/gif")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      image = chunks.last['metadata']
      versions = image['versions']
      expect(image).to_not be_nil
      oid = Pebbles::Uid.parse(image['uid']).last
      expect(oid).to_not be_nil

      versions.each do |version|
        expect(version['url']).to end_with '.jpg'
      end

    end

    it "converts to gif if force_jpeg is set to false" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |_, _, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post) {|_, endpoint, params|
        expect(endpoint).to eq('/jobs')
        expect(params[:params][:input_url]).to end_with("original.gif")

        versions = params[:params][:versions]

        versions.each do |version|
          expect(version[:target_url]).to match(/\d+(sq)?\.gif\?.*/)
        end
      }.once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$?force_jpeg=false", :file => Rack::Test::UploadedFile.new(gif_image, "image/gif")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      image = chunks.last['metadata']
      versions = image['versions']
      expect(image).to_not be_nil
      expect(image['original']).to end_with '.gif'

      versions.each do |version|
        expect(version['url']).to end_with '.gif'
      end

    end

    it "converts to jpeg if force_jpeg is set to false and target format is not in #{TiramisuV1::KEEP_FORMATS}" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |_, _, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post) {|_, endpoint, params|
        expect(endpoint).to eq('/jobs')
        expect(params[:params][:input_url]).to end_with("original.bmp")

        versions = params[:params][:versions]

        versions.each do |version|
          expect(version[:target_url]).to match(/\d+(sq)?\.jpg\?.*/)
          expect(version[:format]).to eq("jpeg")
        end
      }.once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/images/image:realm.app.collection.box$?force_jpeg=false", :file => Rack::Test::UploadedFile.new(bmp_image, "image/bmp")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response

      image = chunks.last['metadata']
      versions = image['versions']
      expect(image).to_not be_nil
      expect(image['original']).to end_with '.bmp'

      versions.each do |version|
        expect(version['url']).to end_with '.jpg'
      end

    end

    it "returns failure as last json chunk if uploaded file are of wrong format" do
      expect_any_instance_of(Pebblebed::Connector).not_to receive(:post)

      post "/images/image:realm.app.collection.box$*", :file => Rack::Test::UploadedFile.new('spec/fixtures/unsupported-format.xml')

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response
      expect(chunks.last['status']).to eq('failed')
      expect(chunks.last['message']).to eq('format-not-supported')
      expect(chunks.last['percent']).to eq(100)
    end

    it "returns failure as last json chunk and includes the error message if something unexpected happens" do
      expect_any_instance_of(AssetStore).to receive(:put).once.and_raise("Unexpected error") # just to make something fail

      expect_any_instance_of(Pebblebed::Connector).not_to receive(:post)

      post "/images/image:realm.app.collection.box$", :file => Rack::Test::UploadedFile.new(uploaded_image, "image/jpeg")

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response
      expect(chunks.last['status']).to eq('failed')
      expect(chunks.last['message']).to eq('Unexpected error')
      expect(chunks.last['percent']).to eq(100)
    end

    it "returns failure as last json chunk if uploaded file is empty" do
      expect_any_instance_of(Pebblebed::Connector).not_to receive(:post)

      post "/images/image:realm.app.collection.box$", :file => Rack::Test::UploadedFile.new('spec/fixtures/empty.jpeg')

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response
      expect(chunks.last['status']).to eq('failed')
      expect(chunks.last['message']).to eq('empty-file')
      expect(chunks.last['percent']).to eq(100)
    end

  end
end
