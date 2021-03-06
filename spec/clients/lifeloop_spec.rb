require 'spec_helper'

describe 'Lifeloop expects' do
  describe 'Create from base oid' do
    it "takes an uid as parameter keeps the reference to it" do
      expect(SecureRandom).to receive(:random_number).and_return 8079809703404923

      created = S3ImageFile.create(Pebbles::Uid.new('image:apdm.lifeloop.oa.birthday'), {:aspect_ratio => 1.333})
      expect(created.uid.to_s).to match /image:apdm\.lifeloop\.oa\.birthday\$\d+\-1333\-.+/
    end
  end

  describe "S3ImageFile" do

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
        expect(S3ImageFile.new(uid).path).to eql 'path/31122012-1337-randomstr/original.jpg'
      end
    end

    describe '#dirname' do
      it "takes an uid as parameter and figures out what the dirname will be" do
        expect(S3ImageFile.new(uid).dirname).to eql 'path/31122012-1337-randomstr'
      end
    end

    describe '#path_for_size' do
      it "generates a path for a given size (version) of the image" do
        expect(S3ImageFile.new(uid).path_for_size(200)).to eql 'path/31122012-1337-randomstr/200.jpg'
      end
      it "generates a path for a given square-sized (version) of the image" do
        expect(S3ImageFile.new(uid).path_for_size(200, :square => true)).to eql 'path/31122012-1337-randomstr/200sq.jpg'
      end
    end
  end
end
