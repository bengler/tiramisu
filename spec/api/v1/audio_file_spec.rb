require 'spec_helper'
require 'vcr'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  describe 'POST /audio_files/:id' do

    let(:json_chunks) { last_response.body.split("\n").map {|chunk| JSON.parse(chunk)} }
    let(:audio_file) {
      'spec/fixtures/yah-rly.mp3' 
    }

    it "submits an audio file and returns a chunked json response with progress data and finally a hash describing it" do

      AssetStore.any_instance.should_receive(:put).once do |url, intercepted|
        while intercepted.read(intercepted.size.to_f / 5.0) ; end # causes progress to be reported
      end

      TootsieHelper.should_receive(:submit_job).once

      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/audio_files/audio:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(audio_file, "audio/mpeg")
      end

      last_response.status.should eq(200)
      chunks = json_chunks
      chunks.first['status'].should eq('received')
      chunks[1]['status'].should eq('transferring')
      chunks.last['status'].should eq('completed')
      chunks.last['percent'].should eq(100)

      audio_file = chunks.last['audio_file']
      audio_file.should_not be_nil

      klass, path, oid = Pebblebed::Uid.parse(audio_file['uid']) 
      klass.should eq('audio')
      path.should eq('realm.app.collection.box')
      oid.should_not be_nil
      
      timestamp, rand, extension, *title = oid.split("-")
      
      extension.should eq "mp3"

      audio_file['baseurl'].should match(/http\:\/\/.+\/#{path.split(".").join("/")}\/#{timestamp}-#{rand}/)

      audio_file['versions'].map{|v| v['format']}.should eq ['mp3', 'flv']
      
      audio_file['original'].should match(/#{audio_file['baseurl']}\/#{title.join("-")}.#{extension}/)

    end
  
    it "returns failure as last json chunk and includes the error message if something unexpected happens" do
  
      AssetStore.any_instance.should_receive(:put).once.and_raise("Funky error")
  
      TootsieHelper.should_not_receive(:submit_job)
  
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        post "/audio_files/audio:realm.app.collection.box", :file => Rack::Test::UploadedFile.new(audio_file, "audio/mpeg")
      end
  
      last_response.status.should eq(200)
      chunks = json_chunks
      chunks.last['status'].should eq('failed')
      chunks.last['message'].should eq('Funky error')
      chunks.last['percent'].should eq(100)
    end
    
  end
  
  describe "GET /audio_files/:uid/status" do
    it "provides an endpont for polling for ready versions of an audio file" do

      HTTPClient
        .any_instance
        .should_receive(:head)
        .exactly(AudioBundle::OUTPUT_FORMATS.length).times
        .and_return(OpenStruct.new(:status_code => 200))

      get "/audio_files/audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording/status"

      data = JSON.parse(last_response.body, :symbolize_names => true)

      data[:versions].map{|v| v[:ready]}.should_not include(false)

    end

    it "provides an endpont for polling for ready versions of an audio file" do

      HTTPClient
        .any_instance
        .should_receive(:head)
        .exactly(AudioBundle::OUTPUT_FORMATS.length).times
        .and_return(OpenStruct.new(:status_code => 300))

      get "/audio_files/audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording/status"
      data = JSON.parse(last_response.body, :symbolize_names => true)

      data[:versions].map{|v| v[:ready]}.should_not include(true)
      
    end
    
  end
  
end
