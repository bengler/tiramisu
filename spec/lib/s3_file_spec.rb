require 'spec_helper'

describe 'S3File' do

  let(:base_uid) { Pebblebed::Uid.new("file:agricult.forestry101.spring12") }
  let(:uid) { Pebblebed::Uid.new("file:agricult.forestry101.spring12$20120329234410-7yv6-pdf-the-training-of-a-forester-by-gifford-pinchot") }

  describe '#new' do
    it "takes an uid as parameter keeps the reference to it" do
      S3File.new(uid).uid.to_s.should eql "file:agricult.forestry101.spring12$20120329234410-7yv6-pdf-the-training-of-a-forester-by-gifford-pinchot"
    end
    it "fails if oid part of the uid is not set" do
      lambda { S3File.new(base_uid) }.should raise_error(S3File::IncompleteUidError)
    end
  end

  describe '#path' do
    it "takes an uid as parameter and figures out what the path will be" do
      S3File.new(uid).path.should eql "agricult/forestry101/spring12/20120329234410-7yv6/the-training-of-a-forester-by-gifford-pinchot.pdf"
    end
    it "takes an uid as parameter and figures out what the dirname will be" do
      S3File.new(uid).dirname.should eql "agricult/forestry101/spring12/20120329234410-7yv6"
    end
  end
end
