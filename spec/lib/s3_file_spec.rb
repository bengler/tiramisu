require 'spec_helper'

describe 'S3File' do

  let(:base_uid) { Pebbles::Uid.new("file:agricult.forestry101.spring12") }
  let(:uid) { Pebbles::Uid.new("file:agricult.forestry101.spring12$20120329234410-7yv6-pdf-the-training-of-a-forester-by-gifford-pinchot") }

  describe '#new' do
    it "takes an uid as parameter keeps the reference to it" do
      expect(S3File.new(uid).uid.to_s).to eql "file:agricult.forestry101.spring12$20120329234410-7yv6-pdf-the-training-of-a-forester-by-gifford-pinchot"
    end
    it "fails if oid part of the uid is not set" do
      expect(lambda { S3File.new(base_uid) }).to raise_error(S3File::IncompleteUidError)
    end
  end

  describe '#path' do
    it "takes an uid as parameter and figures out what the path will be" do
      expect(S3File.new(uid).path).to eql "agricult/forestry101/spring12/20120329234410-7yv6/the-training-of-a-forester-by-gifford-pinchot.pdf"
    end
    it "takes an uid as parameter and figures out what the dirname will be" do
      expect(S3File.new(uid).dirname).to eql "agricult/forestry101/spring12/20120329234410-7yv6"
    end
  end
end
