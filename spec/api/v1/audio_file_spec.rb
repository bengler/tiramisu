require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  describe 'POST /audio_files/:id' do

    let(:chunked_json_response) { last_response.body.split("\n").map {|chunk| JSON.parse(chunk)} }
    let(:audio_file) { 'spec/fixtures/yah-rly.mp3' }

    it "submits an audio file and returns a chunked json response with progress data and finally a hash describing it" do

      expect_any_instance_of(AssetStore).to receive(:put).once do |instance, url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      expect_any_instance_of(Pebblebed::GenericClient).to receive(:post).with("/jobs", anything()).once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/audio_files/audio:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(audio_file, "audio/mpeg")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response
      expect(chunks.first['status']).to eq('received')
      expect(chunks[1]['status']).to eq('transferring')
      expect(chunks.last['status']).to eq('completed')
      expect(chunks.last['percent']).to eq(100)

      audio_file = chunks.last['metadata']
      expect(audio_file).not_to be_nil

      klass, path, oid = Pebbles::Uid.parse(audio_file['uid'])
      expect(klass).to eq('audio')
      expect(path).to eq('realm.app.collection.box')
      expect(oid).not_to be_nil

      timestamp, rand, extension, *title = oid.split("-")

      expect(extension).to eq "mp3"

      expect(audio_file['baseurl']).to match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{timestamp}-#{rand}/)

      expect(audio_file['versions'].map{|v| v['format']}).to eq AudioBundle::OUTPUT_FORMATS.map {|f| f[:format]}

      expect(audio_file['original']).to match(/#{audio_file['baseurl']}\/#{title.join("-")}.#{extension}/)

    end

    it "returns failure as last json chunk and includes the error message if something unexpected happens" do

      expect_any_instance_of(AssetStore).to receive(:put).once.and_raise("Funky error")

      expect_any_instance_of(Pebblebed::GenericClient).not_to receive(:post)

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/audio_files/audio:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(audio_file, "audio/mpeg")
      end

      expect(last_response.status).to eq(200)
      chunks = chunked_json_response
      expect(chunks.last['status']).to eq('failed')
      expect(chunks.last['message']).to eq('Funky error')
      expect(chunks.last['percent']).to eq(100)
    end

  end

  describe "GET /audio_files/:uid/status" do
    it "provides an endpont for polling for ready versions of an audio file" do

      expect_any_instance_of(HTTPClient)
        .to receive(:head)
        .exactly(AudioBundle::OUTPUT_FORMATS.length).times
        .and_return(OpenStruct.new(:status_code => 200))

      get "/audio_files/audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording/status"

      data = JSON.parse(last_response.body)

      expect(data['versions'].map{|v| v['ready']}).to_not include(false)

    end

    it "provides an endpont for polling for ready versions of an audio file" do

      expect_any_instance_of(HTTPClient)
        .to receive(:head)
        .exactly(AudioBundle::OUTPUT_FORMATS.length).times
        .and_return(OpenStruct.new(:status_code => 300))

      get "/audio_files/audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording/status"
      data = JSON.parse(last_response.body)

      expect(data['versions'].map{|v| v['ready']}).to_not include(true)

    end

  end

end
