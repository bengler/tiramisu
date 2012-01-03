class TiramisuV1 < Sinatra::Base

  get '/transactions/:id/progress' do
    stream do |out|
      11.times do |i|
        out << "#{i*10}\n"
        sleep 1
      end
    end
  end

end
