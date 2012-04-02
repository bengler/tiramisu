# A class to transparently intercept all calls to another object
# It works by wrapping a host object and pretending to be that 
# very object. Used here to intercept stream activity and provide
# progress reports. E.g.:

#    intercepted_stream = Interceptor.wrap(tempfile) do |tempfile, method, args|
#      report_progress(tempfile.pos) if method == :read
#    end
#    upload_to_s3(intercepted_stream)

class Interceptor
  def initialize(wrapped, method=nil, callback)
    @method = method
    @wrapped = wrapped
    @callback = callback
  end

  def respond_to?(method)
    @wrapped.respond_to?(method)
  end

  def method_missing(method, *args, &block)
    @callback.call(@wrapped, method, args) if @method.nil? or @method == method
    @wrapped.send(method, *args, &block)
  end

  def self.wrap(wrapped, *args, &block)
    Interceptor.new(wrapped, args[0], block)
  end
end
