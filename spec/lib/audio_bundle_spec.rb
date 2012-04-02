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

  describe "#data" do
    it "provides an image data hash for the client" do

      asset_store.should_receive(:host).any_number_of_times.and_return "example.com"
      asset_store.should_receive(:protocol).any_number_of_times.and_return "http://"

      data = bundle.data

      data[:uid].should eq "audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording"
      data[:baseurl].should eq "http://example.com/area51/secret/unit/20120306122011-ws30-mp3"
      data[:original].should eq "http://example.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording.mp3"

      expected_versions = [
          {:audio_sample_rate=>44100, :audio_bitrate=>64000, :audio_codec=>"libmp3lame", :format=>"mp3", :content_type=>"audio/mpeg", :url=>"http://example.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_64000.mp3"},
          {:audio_sample_rate=>44100, :audio_bitrate=>64000, :format=>"flv", :content_type=>"video/x-flv", :url=>"http://example.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_64000.flv"}
        ]
      data[:versions].should eq expected_versions

    end
  end
  describe "#tootsie_job" do
    it "provides a hash of parameters that can be used to post a transcoding job to tootsie" do

      asset_store.should_receive(:host).any_number_of_times.and_return "example.com"

      tootsie_job = bundle.tootsie_job

      tootsie_job[:params][:input_url].should eq "http://example.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording.mp3"

      expected_versions = [
        {:format=>{:audio_sample_rate=>44100, :audio_bitrate=>64000, :audio_codec=>"libmp3lame", :format=>"mp3", :content_type=>"audio/mpeg"}, :target_url=>"s3:development.o5.no/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_64000.mp3?acl=public_read"},
        {:format=>{:audio_sample_rate=>44100, :audio_bitrate=>64000, :format=>"flv", :content_type=>"video/x-flv"}, :target_url=>"s3:development.o5.no/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_64000.flv?acl=public_read"}
      ]
      tootsie_job[:params][:versions].should eq expected_versions

    end
  end

end
