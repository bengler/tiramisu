require 'mimemagic'

class ImageUtil

  def self.read_metrics(path)
    [file_type(path)] + dimensions(path)
  end


  def self.file_type(path)
    type = mimetype(path)
    return 'psd' if type == 'image/vnd.adobe.photoshop'
    # reduce application/pdf, image/svg+xml etc to what we want
    type.split('/').last.split('+').first
  end


  def self.mimetype(path)
    mime = MimeMagic.by_magic(File.open(path)) || MimeMagic.by_path(File.open(path))
    return mime.to_s
  end


  def self.dimensions(path)
    lines = `vipsheader --all #{path} 2> /dev/null`.split("\n")
    if $?.exitstatus > 0
      # vipsheader failed, find out why
      reason = `vipsheader --all #{path} 2>&1`
      raise StandardError.new('Make sure vipsheader is installed and in your path') if reason.include? 'command not found'
      LOGGER.info("Shell command vipsheader failed. Reason:\n#{reason}")
      return identify_fallback(path)
    end
    width = nil
    height = nil
    orientation = nil
    lines.each do |line|
      width ||= line[/^width\:\s(\d+)/,1]
      height ||= line[/^height\:\s(\d+)/,1]
      orientation ||= line[/^orientation\:\s(\d)/,1]
    end
    orientation ? [width, height, orientation] : [width, height]
  end


  def self.identify_fallback(path)
    return `identify -format '%w %h %[EXIF:Orientation]' #{path}[0] 2> /dev/null`.split(/\s+/)
  end

  def self.force_orientation_on_file(filepath, orientation)
    orientation_id = ORIENTATION_IDS.find_index(orientation) + 1
    `exiftool -ignoreMinorErrors -Orientation=#{orientation_id} -overwrite_original_in_place -n #{filepath}`
  end


  def self.sanitized_image_info(filepath)
    format, width, height, orientation = ImageUtil.read_metrics(filepath)
    if [5, 6, 7, 8].include?(orientation.to_i)
      # Adjust for exif orientation
      width, height = height, width
    end

    width = width && width.to_i
    height = height && height.to_i

    [format, width, height, (width && height && width.to_f / height.to_f) || 0]
  end

end
