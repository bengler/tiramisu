require "spec_helper"

describe AudioBundle do

  let(:s3_config) {
    Tiramisu.config['S3']
  }
  let(:asset_store) {
    store = nil
    VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
      store = AssetStore.new(s3_config)
    end
    store
  }
  let(:audio_file) {
    S3AudioFile.new(Pebbles::Uid.new("audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording"))
  }
  let(:bundle) {
    AudioBundle.new(asset_store, audio_file)
  }

  describe "#metadata" do
    it "provides an image metadata hash for the client" do

      expect(asset_store).to receive(:host).at_least(:once).and_return "apps.o5.no.s3.amazonaws.com"
      expect(asset_store).to receive(:protocol).at_least(:once).and_return "http://"

      metadata = bundle.metadata

      expect(metadata[:uid]).to eq "audio:area51.secret.unit$20120306122011-ws30-mp3-super-rare-recording"
      expect(metadata[:baseurl]).to eq "http://apps.o5.no.s3.amazonaws.com/area51/secret/unit/20120306122011-ws30-mp3"
      expect(metadata[:original]).to eq "http://apps.o5.no.s3.amazonaws.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording.mp3"

      expected_versions = [
          {:audio_sample_rate=>44100, :audio_bitrate=>128000, :audio_codec=>"libmp3lame", :format=>"mp3", :content_type=>"audio/mpeg", :strip_metadata => true, :url=>"http://apps.o5.no.s3.amazonaws.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_128000.mp3"}        ]
      expect(metadata[:versions]).to eq expected_versions

    end
  end
  describe "#to_tootsie_job" do
    it "provides a hash of parameters that can be used to post a transcoding job to tootsie" do

      expect(asset_store).to receive(:host).at_least(:once).and_return "apps.o5.no.s3.amazonaws.com"

      tootsie_job = bundle.to_tootsie_job

      expect(tootsie_job[:params][:input_url]).to eq "http://apps.o5.no.s3.amazonaws.com/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording.mp3"

      expected_versions = [
        {:audio_sample_rate=>44100, :audio_bitrate=>128000, :format=>"mp3", :content_type=>"audio/mpeg", :strip_metadata => true, :target_url=>"s3:development.o5.no/area51/secret/unit/20120306122011-ws30-mp3/super-rare-recording_44100_128000.mp3?acl=public_read", :audio_codec=>"libmp3lame"}
      ]
      expect(tootsie_job[:params][:versions]).to eq expected_versions

    end
  end

end
