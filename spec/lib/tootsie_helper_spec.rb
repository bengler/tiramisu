require 'tootsie_helper'

describe TootsieHelper do

  describe "#job_params" do
    let(:input) do
      {:source=>"pix.jpg", :bucket=>"bucket", :path=>"/0-1333-abc", :notification_url=>"tell_me"}
    end

    let(:file) { stub(:name => '100.jpg', :width => 100) }

    let(:base_output) do
      {"format"=>"jpeg", "strip_metadata"=>true, "medium" => 'web'}
    end

    def target_url(filename)
      "s3:bucket//0-1333-abc/#{file_name}?acl=public_read"
    end

    it "creates multiple versions" do
      options = input.merge(:sizes => [{:width => 100}, {:width => 200}])
      job = TootsieHelper.send(:job_params, options)
      job[:versions].length.should eq(2)
    end

    it "defaults medium to 'web'" do
      options = input.merge(:sizes => [{:width => 100}])
      job = TootsieHelper.send(:job_params, options)
      job[:versions].first["medium"].should eq('web')
    end

    it "can override medium" do
      options = input.merge(:sizes => [{:width => 100, :medium => 'print'}])
      job = TootsieHelper.send(:job_params, options)[:versions].first
      job["medium"].should eq('print')
    end

    it "defaults to using original aspect ratio" do
      options = input.merge(:sizes => [{:width => 100}])
      job = TootsieHelper.send(:job_params, options)[:versions].first
      job["width"].should eq(100)
      job["scale"].should be_nil
      job["crop"].should be_nil
      job["height"].should be_nil
    end

    it "can specify a square" do
      options = input.merge(:sizes => [{:width => 100, :square => true}])
      job = TootsieHelper.send(:job_params, options)[:versions].first
      job["height"].should eq(100)
      job["crop"].should be_true
      job["scale"].should eq('fit')
    end
  end
end
