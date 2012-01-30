require 'image_bundle'

describe ImageBundle do
  describe "#sizes" do
    it "delivers an array of hashes" do
      store = stub(:s3_store, :protocol => 'http://', :host => 'example.com')
      expected = [
        {:width=>100, :square=>false, :url=>"http://example.com/path/oid/100.jpg"},
        {:width=>100, :square=>true, :url=>"http://example.com/path/oid/100sq.jpg"},
        {:width=>300, :square=>false, :url=>"http://example.com/path/oid/300.jpg"},
        {:width=>500, :square=>true, :url=>"http://example.com/path/oid/500sq.jpg"},
        {:width=>700, :square=>false, :url=>"http://example.com/path/oid/700.jpg"},
        {:width=>1000, :square=>false, :url=>"http://example.com/path/oid/1000.jpg"},
        {:width=>5000, :square=>false, :url=>"http://example.com/path/oid/5000.jpg"}
      ]
      bundle = ImageBundle.new(store, :location => 'path', :aspect_ratio => 0.7)
      bundle.stub(:oid => 'oid')
      bundle.sizes.should eq(expected)
    end
  end
end
