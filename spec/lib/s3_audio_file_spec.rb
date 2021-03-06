require 'spec_helper'

describe 'S3AudioFile' do

  let(:base_uid) { Pebbles::Uid.new('audio:path.to') }
  let(:uid) { Pebbles::Uid.new("audio:path.to$31122012-randomstr-mp3-super-funky-tunes") }

  describe '#new' do
    it "takes an uid as parameter keeps the reference to it" do
      expect(S3AudioFile.new(uid).uid.to_s).to eql "audio:path.to$31122012-randomstr-mp3-super-funky-tunes"
    end
    it "fails if oid part of the uid is not set" do
      expect(lambda { S3AudioFile.new(base_uid) }).to raise_error(S3File::IncompleteUidError)
    end
  end

  describe '#path' do
    it "includes original file format as a part of the path" do
      expect(S3AudioFile.new(uid).path).to eql 'path/to/31122012-randomstr-mp3/super-funky-tunes.mp3'
    end
  end

  describe '#dirname' do
    it "takes an uid as parameter and figures out what the dirname will be" do
      expect(S3AudioFile.new(uid).dirname).to eql 'path/to/31122012-randomstr-mp3'
    end
  end

  describe '#path_for_version' do
    it "generates a path for a version with a given sample rate of the audio file" do
      file = S3AudioFile.new(uid)
      expect(file.path_for_version(:audio_sample_rate => 44100)).to eql 'path/to/31122012-randomstr-mp3/super-funky-tunes_44100.mp3'
    end
    it "generates a path for a version with a given bitrate of the audio file" do
      file = S3AudioFile.new(uid)
      expect(file.path_for_version(:audio_bitrate => 64000)).to eql 'path/to/31122012-randomstr-mp3/super-funky-tunes_64000.mp3'
    end
    it "generates a path for a version with a given format, sample rate and bitrate" do
      file = S3AudioFile.new(uid)
      path = file.path_for_version :audio_bitrate => 64000, :audio_sample_rate => 44100, :format => 'flv'
      expect(path).to eql 'path/to/31122012-randomstr-mp3/super-funky-tunes_44100_64000.flv'
    end
  end
end
