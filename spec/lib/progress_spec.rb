require 'tiramisu/progress'
require 'json'

describe Progress do
  let(:stream) { StringIO.new }
  let(:progress) { Progress.new(stream) }

  it 'reports to a stream' do
    progress.report(:hello => :world)
    expect(stream.string).to eq("{\"hello\":\"world\"}\n")
  end

  it "reports received" do
    progress.received
    expect(stream.string).to eq("{\"percent\":0,\"status\":\"received\"}\n")
  end

  it "reports transferring" do
    progress.transferring(0.7)
    expect(stream.string).to eq("{\"percent\":63,\"status\":\"transferring\"}\n")
  end

  it "reports failure" do
    progress.failed('sucks to be you')
    expect(stream.string).to eq("{\"percent\":100,\"status\":\"failed\",\"message\":\"sucks to be you\"}\n")
  end

  it "reports completion" do
    progress.completed(:something => "extra")
    expect(stream.string).to eq("{\"percent\":100,\"status\":\"completed\",\"something\":\"extra\"}\n")
  end
end
