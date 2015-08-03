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
    S3ImageFile.new(Pebbles::Uid.new("image:area51.secret.unit$20120306122011-1498-uuva"))
  }

  describe "#metadata" do
    it "provides an image metadata hash for the client" do

      expect(asset_store).to receive(:host).at_least(:once).and_return "example.com"
      expect(asset_store).to receive(:protocol).at_least(:once).and_return "http://"

      bundle = ImageBundle.new(asset_store, image_file, {
                                              format: 'jpeg',
                                              height: 1080,
                                              width: 1920,
                                              aspect_ratio: 16.0/9.0
                                          })

      metadata = bundle.metadata

      expect(metadata[:uid]).to eq "image:area51.secret.unit$20120306122011-1498-uuva"
      expect(metadata[:baseurl]).to eq "http://example.com/area51/secret/unit/20120306122011-1498-uuva"
      expect(metadata[:original]).to eq "http://example.com/area51/secret/unit/20120306122011-1498-uuva/original.jpg"
      expect(metadata[:aspect_ratio]).to eq 1.498

      expected_versions = [
        {:width => 100, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/100.jpg"},
        {:width => 100, :square => true, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/100sq.jpg"},
        {:width => 300, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/300.jpg"},
        {:width => 500, :square => true, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/500sq.jpg"},
        {:width => 700, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/700.jpg"},
        {:width => 1000, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/1000.jpg"},
        {:width => 1600, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/1600.jpg"},
        {:width => 1920, :square => false, :url => "http://example.com/area51/secret/unit/20120306122011-1498-uuva/1920.jpg"}
      ]
      expect(metadata[:versions]).to eq expected_versions

    end
  end
  describe "#tootsie_job" do
    it "provides a hash of parameters that can be used to post a transcoding job to tootsie" do

      expect(asset_store).to receive(:host).at_least(:once).and_return "example.com"

      bundle = ImageBundle.new(asset_store, image_file, {
                                              format: 'jpeg',
                                              height: 1080,
                                              width: 1920,
                                              aspect_ratio: 16.0/9.0
                                          })

      tootsie_job = bundle.to_tootsie_job

      expect(tootsie_job[:params][:input_url]).to eq "http://example.com/area51/secret/unit/20120306122011-1498-uuva/original.jpg"

      expected_versions = [
          {
          :format => "jpeg",
          :width => 100,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/100.jpg?acl=public_read"
        },
        {
          :scale => "fit",
          :height => 100,
          :crop => true,
          :format => "jpeg",
          :width => 100,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/100sq.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 300,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/300.jpg?acl=public_read"
        },
        {
          :scale => "fit",
          :height => 500,
          :crop => true,
          :format => "jpeg",
          :width => 500,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/500sq.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 700,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/700.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 1000,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/1000.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 1600,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/1600.jpg?acl=public_read"
        },
        {
          :format => "jpeg",
          :width => 1920,
          :strip_metatadata => true,
          :medium => "web",
          :target_url => "s3:development.o5.no/area51/secret/unit/20120306122011-1498-uuva/1920.jpg?acl=public_read"
        }
      ]
      expect(tootsie_job[:params][:versions]).to eq expected_versions

    end
  end

  it "does not convert gif to jpeg" do

    expect(SecureRandom).to receive(:random_number).and_return 807980

    expect(asset_store).to receive(:host).at_least(:once).and_return "example.com"

    s3_file = S3ImageFile.create("image:area51.secret.unit",
                                 :original_extension => 'gif',
                                 :extension => 'gif',
                                 :aspect_ratio => 1.498)

    bundle = ImageBundle.new(asset_store, s3_file, {
                                            format: 'gif',
                                            height: 1080,
                                            width: 1920,
                                            aspect_ratio: 16.0/9.0
                                        })

    tootsie_job = bundle.to_tootsie_job

    expect(tootsie_job[:params][:input_url]).to match /http:\/\/example\.com\/area51\/secret\/unit\/\d+-1498-\w+\/original\.gif/

    versions = tootsie_job[:params][:versions]

    versions.each do |version|
      expect(version[:format]).to eq('gif')
      expect(version[:target_url]).to match /s3:development\.o5\.no\/area51\/secret\/unit\/\d+-1498-\w+\/\d+(sq)?.gif\?acl=public_read/
    end
  end
end
