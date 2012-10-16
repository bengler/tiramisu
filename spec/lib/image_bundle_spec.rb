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
    ImageBundle.new(asset_store, image_file)
  }

  describe "#metadata" do
    it "provides an image metadata hash for the client" do

      asset_store.should_receive(:host).any_number_of_times.and_return "example.com"
      asset_store.should_receive(:protocol).any_number_of_times.and_return "http://"

      metadata = bundle.metadata

      metadata[:uid].should eq "image:area51.secret.unit$20120306122011-1498-9et0"
      metadata[:baseurl].should eq "http://example.com/area51/secret/unit/20120306122011-1498-9et0"
      metadata[:original].should eq "http://example.com/area51/secret/unit/20120306122011-1498-9et0/original.jpg"
      metadata[:aspect_ratio].should eq 1.498

      expected_versions = [
        {:width => 100, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/100.jpg"},
        {:width => 100, :square => true, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/100sq.jpg"},
        {:width => 300, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/300.jpg"},
        {:width => 500, :square => true, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/500sq.jpg"},
        {:width => 700, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/700.jpg"},
        {:width => 1000, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/1000.jpg"},
        {:width => 5000, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-9et0/5000.jpg"}
      ]
      metadata[:versions].should eq expected_versions

    end
  end
  describe "#tootsie_job" do
    it "provides a hash of parameters that can be used to post a transcoding job to tootsie" do

      asset_store.should_receive(:host).any_number_of_times.and_return "example.com"

      tootsie_job = bundle.to_tootsie_job

      tootsie_job[:params][:input_url].should eq "http://example.com/area51/secret/unit/20120306122011-1498-9et0/original.jpg"

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
          :width => 5000,
          :strip_metatadata => true,
          :medium => "print",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/5000.jpg?acl=public_read"
        }
      ]
      tootsie_job[:params][:versions].should eq expected_versions

    end
  end

end
