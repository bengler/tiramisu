require 'spec_helper'

describe 'S3ImageFile' do

  let(:base_uid) { Pebbles::Uid.new('image:path') }
  let(:aspect_ratio) { 1337 }
  let(:uid) { Pebbles::Uid.new("image:path$31122012-#{aspect_ratio}-randomstr") }

  describe '#new' do
    it "takes an uid as parameter keeps the reference to it" do
      expect(S3ImageFile.new(uid).uid.to_s).to eql "image:path$31122012-1337-randomstr"
    end
    it "fails if oid part of the uid is not set" do
      expect(lambda { S3ImageFile.new(base_uid) }).to raise_error(S3File::IncompleteUidError)
    end
  end

  describe '#path' do
    it "includes the aspect ratio as a part of the path" do
      expect(S3ImageFile.new(uid, {original_extension: 'png'}).path).to eql 'path/31122012-1337-randomstr/original.png'
    end
  end

  describe '#dirname' do
    it "takes an uid as parameter and figures out what the dirname will be" do
      expect(S3ImageFile.new(uid).dirname).to eql 'path/31122012-1337-randomstr'
    end
  end

  describe '#path_for_size' do
    it "generates a path for a given size (version) of the image" do
      expect(S3ImageFile.new(uid).path_for_size(200, extension: 'png')).to eql 'path/31122012-1337-randomstr/200.png'
    end
    it "generates a path for a given square-sized (version) of the image" do
      expect(S3ImageFile.new(uid).path_for_size(200, square: true, extension: 'png')).to eql 'path/31122012-1337-randomstr/200sq.png'
    end
  end
end
