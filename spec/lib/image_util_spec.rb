require "spec_helper"

expected_mimetypes = {
  bmp: 'image/bmp',
  gif: 'image/gif',
  jpg: 'image/jpeg',
  pdf: 'application/pdf',
  png: 'image/png',
  svg: 'image/svg+xml',
  tiff: 'image/tiff',
  psd: 'image/vnd.adobe.photoshop'
}

describe ImageUtil do

  context 'mimetype' do
    # filename logic: <actual_mimetype>_<whatever>.<alleged_mimetype>
    it 'finds the correct mimetype' do
      dir = './spec/fixtures/strange_image_files/'
      Dir.foreach(dir) do |filename|
        next if ['.', '..', '.DS_Store'].include? filename
        file_format = filename.split('.').first.split('_').first # bmp_borked.bmp -> bmp
        fullpath = "#{dir}#{filename}"
        mimetype = ImageUtil.mimetype(fullpath)
        expect(mimetype).to eq(expected_mimetypes[file_format.to_sym])
      end
    end
  end

  context 'empty file' do
    let(:empty_file_path) {
       './spec/fixtures/empty.jpeg'
    }

    it 'finds mimetype' do
      mimetype = ImageUtil.mimetype(empty_file_path)
      expect(mimetype).to eq('image/jpeg')
    end

    it 'return empty dimensions' do
      dimensions = ImageUtil.dimensions(empty_file_path)
      expect(dimensions).to eq([])
    end
  end


  context 'metrics' do

    it 'figures out image metrics' do
      path = './spec/fixtures/strange_image_files/jpg.jpg'
      expect(ImageUtil).not_to receive(:identify_fallback)
      metrics = ImageUtil.read_metrics(path)
      expect(metrics).to eq(['jpeg', '1024', '680'])
    end

    it 'reads orientation' do
      path = './spec/fixtures/rotated.jpg'
      expect(ImageUtil).not_to receive(:identify_fallback)
      metrics = ImageUtil.read_metrics(path)
      expect(metrics).to eq(['jpeg', '450', '600', '8'])
    end

    it 'reads bmp file even if its borked' do
      path = './spec/fixtures/strange_image_files/bmp_borked.bmp'
      expect(ImageUtil).to receive(:identify_fallback).and_call_original
      metrics = ImageUtil.read_metrics(path)
      expect(metrics).to eq(['bmp', '99', '100'])
    end

    it 'reads psd files' do
      path = './spec/fixtures/strange_image_files/psd.psd'
      expect(ImageUtil).to receive(:identify_fallback).and_call_original
      metrics = ImageUtil.read_metrics(path)
      expect(metrics).to eq(['psd', '33', '50'])
    end

    it 'infers correct aspect_ratio' do
      path = './spec/fixtures/iphone_portrait.jpg'
      expect(ImageUtil).not_to receive(:identify_fallback)
      image_info = ImageUtil.sanitized_image_info(path)
      expect(image_info).to eq(['jpeg', 3024, 4032, 0.75])
    end

  end

end
