require "spec_helper"

describe AssetStore do
  describe "#sizes" do

    let(:config) {
      YAML::load(File.open("config/services.yml"))[ENV['RACK_ENV']]['S3']
    }
    it "figures out the url of a path" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        store = AssetStore.new(config)
        store.url_for("a/path/with/file.ext").should eql "http://development.o5.no.s3.amazonaws.com/a/path/with/file.ext"  
      end
    end
    it "figures out the S3 url of a path" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        AssetStore.new(config).s3_url_for("this/is/a/path").should eql "s3:development.o5.no/this/is/a/path"  
      end
    end
    it "transfers a file to bucket" do
      VCR.use_cassette('S3', :match_requests_on => [:method, :host]) do
        AssetStore.new(config).put("s3:development.o5.no/dummy/content", "dummy content").should be true
      end
    end
  end
end
