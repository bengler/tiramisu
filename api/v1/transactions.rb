class TiramisuV1 < Sinatra::Base

  get '/transactions/:id/progress' do |transaction_id|
    response['X-Accel-Buffering'] = 'no'
    stream do |out|
      ProgressTracker.track(transaction_id) do |progress|
        out << "#{progress}\n"
      end
    end
  end

end
