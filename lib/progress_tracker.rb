# Used to exchange progress information between processes. Typically
# the upload handler reports progress with #report while 
# transactions/:id/progress tracks progress with #track.
# Memcached is used for communications.

class ProgressTracker
  def initialize(memcached)
    @memcached = memcached
  end

  # Reports an amount of progress for a specific transaction
  def report(transaction, progress)
    return unless transaction
    @memcached.set("progress:#{transaction}", progress, 60)
  end

  # Tracks the progress of a transaction. The block will be called once with
  # the current progress value, then each time the value changes. When the
  # value reaches 100 the method returns.
  def track(transaction, &block)
    progress = -1
    while (progress < 100) do
      new_progress = @memcached.get("progress:#{transaction}").to_i
      if new_progress != progress
        yield(new_progress)
        progress = new_progress
      else
        sleep 0.5
      end      
    end
  end
end