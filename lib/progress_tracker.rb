# Used to exchange progress information between requests. Typically
# the upload handler reports progress with #report while 
# transactions/:id/progress tracks progress with #track.
# Memcached is used for communications

class ProgressTracker
  def initialize(memcached)
    @memcached = memcached
  end

  def report(transaction, progress)
    puts "report(#{transaction.inspect}, #{progress.inspect})"
    @memcached.set("progress:#{transaction}", progress, 60)
  end

  def track(transaction, &block)
    progress = -1
    while (progress < 100) do
      new_progress = @memcached.get("progress:#{transaction}").to_i
      puts "tracked #{transaction.inspect} with #{new_progress}"
      if new_progress != progress
        yield(new_progress)
        progress = new_progress
      else
        sleep 0.5
      end      
    end
  end
end