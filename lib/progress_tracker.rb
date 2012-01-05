# Used to exchange progress information between processes. Typically
# the upload handler reports progress with #report while 
# transactions/:id/progress tracks progress with #track.

# This class assumes RabbitMQ is configured on the localhost

module ProgressTracker
  # Sends a progress report for a specific transaction. Message must start with 
  # a number in the range 0..100. The rest of the string can be whatever you
  # prefer and is forwarded to the tracking client with no processing.
  # Messages will only be forwarded when the progress number increases.
  def self.report(transaction, progress)
    return unless transaction
    Carrot.queue("progress:#{transaction}", :auto_delete => true).publish(progress.to_s)
  end

  # Tracks the progress of a transaction. The block will be called once with
  # the current progress value, then each time the value changes. When the
  # value reaches 100 the method returns.
  def self.track(transaction, &block)
    queue = Carrot.queue("progress:#{transaction}", :auto_delete => true)
    progress = -1
    while (progress < 100) do
      new_progress = queue.pop
      if new_progress && new_progress.to_i > progress
        yield(new_progress)
        progress = new_progress.to_i
      else
        sleep 0.5
      end      
    end
  end
end