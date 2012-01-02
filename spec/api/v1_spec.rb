require 'spec_helper'

describe 'API v1' do
  include Rack::Test::Methods

  def app
    TiramisuV1
  end

  god_endpoints = [
    {:method => :post, :endpoint => '/a_resource'},
    {:method => :put, :endpoint => '/a_resource/id'},
  ]

  user_endpoints = [
    {:method => :get, :endpoint => '/a_resource/id'}
  ]

  let(:json_output) { JSON.parse(last_response.body) }

  context "with a logged in god" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id => 1337, :god => true, :realm => 'rock_and_roll'}))
    end

    it "does powerful stuff"

  end

  context "with a logged in user" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id => 1337, :god => false, :realm => 'rock_and_roll'}))
    end

    it "accesses all sorts of things"

    describe "has no access to god endpoints" do
      god_endpoints.each do |forbidden|
        it "fails to #{forbidden[:method]} #{forbidden[:endpoint]}" do
          self.send(forbidden[:method], forbidden[:endpoint])
          last_response.status.should eq(403)
        end
      end
    end
  end

  describe "with no current user" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {}))
    end

    it "mostly gets harmless stuff"

    describe "has no access to god endpoints" do
      god_endpoints.each do |forbidden|
        it "fails to #{forbidden[:method]} #{forbidden[:endpoint]}" do
          self.send(forbidden[:method], forbidden[:endpoint])
          last_response.status.should eq(403)
        end
      end
    end

    describe "has no access to user endpoints" do
      user_endpoints.each do |forbidden|
        it "fails to #{forbidden[:method]} #{forbidden[:endpoint]}" do
          self.send(forbidden[:method], forbidden[:endpoint])
          last_response.status.should eq(403)
        end
      end
    end
  end

end
