require "spec_helper"

describe AudioBundle do

  let(:s3_config) {
    YAML::load(File.open("config/services.yml"))[ENV['RACK_ENV']]['S3']
  }
  let(:asset_store) {
    store = nil
    VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
      store = AssetStore.new(s3_config)
    end
    store
  }
  let(:audio_file) {
    S3AudioFile.new(Pebblebed::Uid.new("audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording"))
  }
  let(:bundle) {
    AudioBundle.new(asset_store, audio_file)
  }

  describe "#metadata" do
    it "provides an image metadata hash for the client" do

      asset_store.should_receive(:host).any_number_of_times.and_return "example.com"
      asset_store.should_receive(:protocol).any_number_of_times.and_return "http://"

      metadata = bundle.metadata

      metadata[:uid].should eq "audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording"
      metadata[:baseurl].should eq "http://example.com/area51/secret/unit/20120306122011-ws30-mp3"
      metadata[:original].should eq "http://example.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording.mp3"

      expected_versions = [
          {:audio_sample_rate=>44100, :audio_bitrate=>128000, :audio_codec=>"libmp3lame", :format=>"mp3", :content_type=>"audio/mpeg", :strip_metadata => true, :url=>"http://example.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_128000.mp3"}        ]
      metadata[:versions].should eq expected_versions

    end
  end
  describe "#to_tootsie_job" do
    it "provides a hash of parameters that can be used to post a transcoding job to tootsie" do

      asset_store.should_receive(:host).any_number_of_times.and_return "example.com"

      tootsie_job = bundle.to_tootsie_job

      tootsie_job[:params][:input_url].should eq "http://example.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording.mp3"

      expected_versions = [
        {:audio_sample_rate=>44100, :audio_bitrate=>128000, :format=>"mp3", :content_type=>"audio/mpeg", :strip_metadata => true, :target_url=>"s3:development.o5.no/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_128000.mp3?acl=public_read", :audio_codec=>"libmp3lame"}
      ]
      tootsie_job[:params][:versions].should eq expected_versions

    end
  end

end
