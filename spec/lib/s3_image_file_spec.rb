require 'spec_helper'

describe 'S3ImageFile' do

  let(:base_uid) { Pebblebed::Uid.new('image:path') }
  let(:aspect_ratio) { 1337 }
  let(:uid) { Pebblebed::Uid.new("image:path$timestamp-randomstr-extension-super-crazy-title-#{aspect_ratio}") }

  describe '#new' do
    it "takes an uid as parameter keeps the reference to it" do
      S3ImageFile.new(uid).uid.to_s.should eql "image:path$timestamp-randomstr-extension-super-crazy-title-1337"
    end
    it "fails if oid part of the uid is not set" do
      lambda { S3ImageFile.new(base_uid) }.should raise_error(S3File::IncompleteUidError)
    end
  end

  describe '#path' do
    it "includes the aspect ratio as a part of the path" do
      S3ImageFile.new(uid).path.should eql 'path/timestamp-randomstr-1337/super-crazy-title.extension'
    end
  end

  describe '#dirname' do
    it "takes an uid as parameter and figures out what the dirname will be" do
      S3ImageFile.new(uid).dirname.should eql 'path/timestamp-randomstr-1337'
    end
  end
end
