require "spec_helper"

describe ImageBundle do

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
  let(:image_file) {
    S3ImageFile.new(Pebbles::Uid.new("image:area51.secret.unit$20120306122011-1498-9et0"))
  }
  let(:bundle) {
    ImageBundle.new(asset_store, image_file, {height: 900, width: 1600})
  }

  describe "#metadata" do
    it "provides an image metadata hash for the client" do

      expect(asset_store).to receive(:host).at_least(:once).and_return "example.com"
      expect(asset_store).to receive(:protocol).at_least(:once).and_return "http://"

      metadata = bundle.metadata

      expect(metadata[:uid]).to eq "image:area51.secret.unit$20120306122011-1498-9et0"
      expect(metadata[:baseurl]).to eq "http://example.com/area51/secret/unit/20120306122011-1498-9et0"
      expect(metadata[:original]).to eq "http://example.com/area51/secret/unit/20120306122011-1498-9et0/original.jpg"
      expect(metadata[:aspect_ratio]).to eq 1.498

      expected_versions = [
        {:width => 100, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/100.jpg"},
        {:width => 100, :square => true, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/100sq.jpg"},
        {:width => 300, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/300.jpg"},
        {:width => 500, :square => true, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/500sq.jpg"},
        {:width => 700, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/700.jpg"},
        {:width => 1000, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/1000.jpg"},
        {:width => 1600, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/1600.jpg"}
      ]
      expect(metadata[:versions]).to eq expected_versions

    end
  end
  describe "#tootsie_job" do
    it "provides a hash of parameters that can be used to post a transcoding job to tootsie" do

      expect(asset_store).to receive(:host).at_least(:once).and_return "example.com"

      tootsie_job = bundle.to_tootsie_job

      expect(tootsie_job[:params][:input_url]).to eq "http://example.com/area51/secret/unit/20120306122011-1498-9et0/original.jpg"

      expected_versions = [
        {
          :format => "jpeg",
          :width => 100,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/100.jpg?acl=public_read"
        },
        {
          :scale => "fit",
          :height => 100,
          :crop => true,
          :format => "jpeg",
          :width => 100,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/100sq.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 300,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/300.jpg?acl=public_read"
        },
        {
          :scale => "fit",
          :height => 500,
          :crop => true,
          :format => "jpeg",
          :width => 500,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/500sq.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 700,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/700.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 1000,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/1000.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 1600,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/1600.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 2048,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/2048.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 3000,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/3000.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 5000,
          :strip_metatadata => true,
          :medium => "print",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/5000.jpg?acl=public_read"
        }
      ]
      expect(tootsie_job[:params][:versions]).to eq expected_versions

    end
  end

end
