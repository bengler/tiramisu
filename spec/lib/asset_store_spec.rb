require "spec_helper"

describe AssetStore do
  describe "#sizes" do

    let(:config) { Tiramisu.config['S3'] }

    it "figures out the url of a path" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        store = AssetStore.new(config)
        expect(store.url_for("a/path/with/file.ext")).to eql "http://development.o5.no.s3.amazonaws.com/a/path/with/file.ext"
      end
    end
    it "figures out the S3 url of a path" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        expect(AssetStore.new(config).s3_url_for("this/is/a/path")).to eql "s3:development.o5.no/this/is/a/path"
      end
    end
    it "transfers a file to bucket" do
      # pending "Can't figure out how to test this without actually putting content on the server"
      # fail("Pending")
      VCR.use_cassette('S3-put', :match_requests_on => [:method, :host]) do
        expect(AssetStore.new(config).put("s3:development.o5.no/dummy/content", "dummy content")).to be true
      end
    end
  end
end
