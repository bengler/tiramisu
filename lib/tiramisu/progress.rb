class Progress

  attr_accessor :stream

  def initialize(stream)
    self.stream = stream
  end

  def report(progress)
    self.stream << "#{progress.to_json}\n"
  end

  def status(percent, message, details = {})
    {:percent => percent, :status => message}.merge details
  end

  def received
    report status(0, 'received')
  end

  def transferring(progress)
    report status((progress*90).round, 'transferring')
  end

  def failed(message)
    report status(100, 'failed', :message => message)
  end

  def completed(details = {})
    report status(100, 'completed').merge details
  end
end
