require 'progress'
require 'json'

describe Progress do
  let(:stream) { StringIO.new }
  let(:progress) { Progress.new(stream) }

  it 'reports to a stream' do
    progress.report(:hello => :world)
    stream.string.should eq("{\"hello\":\"world\"}\n")
  end

  it "reports received" do
    progress.received
    stream.string.should eq("{\"percent\":0,\"status\":\"received\"}\n")
  end

  it "reports transferring" do
    progress.transferring(0.7)
    stream.string.should eq("{\"percent\":63,\"status\":\"transferring\"}\n")
  end

  it "reports failure" do
    progress.failed('sucks to be you')
    stream.string.should eq("{\"percent\":100,\"status\":\"failed\",\"message\":\"sucks to be you\"}\n")
  end

  it "reports completion" do
    progress.completed(:something => "extra")
    stream.string.should eq("{\"percent\":100,\"status\":\"completed\",\"something\":\"extra\"}\n")
  end
end
