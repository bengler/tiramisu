require 'image_bundle'
require 'asset_store'
require 's3_file'
require 's3_image_file'
require 'pebblebed'

describe ImageBundle do
  describe "#tootsie_job" do
    it "delivers a hash of parameters that can be used to post a transcoding job to tootsie" do
      expected_params = [
        {:width=>100, :square=>false, :url=>"http://example.com/path/timestamp-randstr-aspect/title_100.jpg"},
        {:width=>100, :square=>true, :url=>"http://example.com/path/timestamp-randstr-aspect/title_100_sq.jpg"},
        {:width=>300, :square=>false, :url=>"http://example.com/path/timestamp-randstr-aspect/title_300.jpg"},
        {:width=>500, :square=>true, :url=>"http://example.com/path/timestamp-randstr-aspect/title_500_sq.jpg"},
        {:width=>700, :square=>false, :url=>"http://example.com/path/timestamp-randstr-aspect/title_700.jpg"},
        {:width=>1000, :square=>false, :url=>"http://example.com/path/timestamp-randstr-aspect/title_1000.jpg"},
        {:width=>5000, :square=>false, :url=>"http://example.com/path/timestamp-randstr-aspect/title_5000.jpg"}
      ]
      #s3_image = ImageBundle.new(Pebblebed::Uid.new('image:path$timestamp-randstr-jpg-title-aspect'))
      #bundle = ImageBundle.new(store, s3_image)
      #bundle.image_data[:versions].should eq(expected)
    end
  end
=begin
require 'tootsie_helper'

describe TootsieHelper do

  describe "#generate_image_sizes" do
    xit "creates and submits a scaling job"
  end
  
  describe "#submit_job" do
    xit "accepts a raw parameter hash and submits a job to tootsie"
  end
  
  describe "#image_scaling_job_params" do
    let(:input) do
      {:source => "pix.jpg", :bucket => "bucket", :path => "/0-1333-abc", :notification_url => "tell_me"}
    end

    let(:file) { stub(:name => '100.jpg', :width => 100) }

    let(:base_output) do
      {"format" => "jpeg", "strip_metadata" => true, "medium" => 'web'}
    end

    def target_url(filename)
      "s3:bucket//0-1333-abc/#{filename}?acl=public_read"
    end

    it "creates multiple versions" do
      options = input.merge(:sizes => [{:width => 100}, {:width => 200}])
      job = TootsieHelper.send(:image_scaling_job_params, options)
      job[:params][:versions].length.should eq(2)
    end

    xit "defaults medium to 'web'" do
      options = input.merge(:sizes => [{:width => 100}])
      job = TootsieHelper.send(:image_scaling_job_params, options)
      job[:params][:versions].first[:medium].should eq('web')
    end

    xit "can override medium" do
      options = input.merge(:sizes => [{:width => 100, :medium => 'print'}])
      job = TootsieHelper.send(:image_scaling_job_params, options)
      job[:params][:versions].first[:medium].should eq('print')
    end

    xit "defaults to using original aspect ratio" do
      options = input.merge(:sizes => [{:width => 100}])
      job = TootsieHelper.send(:image_scaling_job_params, options)
      first_param = job[:params][:versions].first
      first_param[:width].should eq(100)
      first_param[:scale].should be_nil
      first_param[:crop].should be_nil
      first_param[:height].should be_nil
    end

    xit "can specify a square" do
      options = input.merge(:sizes => [{:width => 100, :square => true}])
      job = TootsieHelper.send(:image_scaling_job_params, options)
      first_param = job[:params][:versions].first
      first_param[:height].should eq(100)
      first_param[:crop].should be_true
      first_param[:scale].should eq('fit')
    end
  end
end

=end
end
