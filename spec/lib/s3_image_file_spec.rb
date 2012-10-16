require 'spec_helper'

describe 'S3ImageFile' do

  let(:base_uid) { Pebbles::Uid.new('image:path') }
  let(:aspect_ratio) { 1337 }
  let(:uid) { Pebbles::Uid.new("image:path$31122012-#{aspect_ratio}-randomstr") }

  describe '#new' do
    it "takes an uid as parameter keeps the reference to it" do
      S3ImageFile.new(uid).uid.to_s.should eql "image:path$31122012-1337-randomstr"
    end
    it "fails if oid part of the uid is not set" do
      lambda { S3ImageFile.new(base_uid) }.should raise_error(S3File::IncompleteUidError)
    end
  end

  describe '#path' do
    it "includes the aspect ratio as a part of the path" do
      S3ImageFile.new(uid).path.should eql 'path/31122012-1337-randomstr/original.jpg'
    end
  end

  describe '#dirname' do
    it "takes an uid as parameter and figures out what the dirname will be" do
      S3ImageFile.new(uid).dirname.should eql 'path/31122012-1337-randomstr'
    end
  end

  describe '#path_for_size' do
    it "generates a path for a given size (version) of the image" do
      S3ImageFile.new(uid).path_for_size(200).should eql 'path/31122012-1337-randomstr/200.jpg'
    end
    it "generates a path for a given square-sized (version) of the image" do
      S3ImageFile.new(uid).path_for_size(200, :square => true).should eql 'path/31122012-1337-randomstr/200sq.jpg'
    end
  end
end
