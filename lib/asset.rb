class Asset

  def self.host
    'http://amazon.bucket/'
  end

  attr_accessor :id

  def initialize(id)
    self.id = id
  end

  def basepath
    "#{Asset.host}#{id.split('.').join('/')}/#{oid}"
  end

  def uid
    "asset:#{id}$#{oid}"
  end

  def oid
    "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{(aspect_ratio * 1000).to_i}-#{unique_identifier}"
  end

  def aspect_ratio
    0.789
  end

  def unique_identifier
    @uniq_identifier ||= srand(1000).to_s(36)
  end

  def sizes
    {'100' => "#{basepath}/100.jpg", '300' => nil, '500' => nil, '1000' => nil, '5000' => nil}
  end

  def original_image
    "#{basepath}/original.png"
  end

end


