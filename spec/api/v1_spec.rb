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

    describe "assets" do
      before(:each) do
        Timecop.freeze(Time.utc(2012, 01, 04, 13, 17, 48))
        Asset.any_instance.stub(:unique_identifier => 'c82akjt4onjli7qgnbwfz4ltw')
      end

      after(:each) { Timecop.return }

      describe 'POST /assets/:id' do
        it "submits an asset" do
          post "/assets/realm.app.collection.box", :transaction_id => 'xyz', :notification_url => 'the_url'
          last_response.status.should eq(201)
          asset = json_output['image']
          asset['id'].should eq('asset:realm.app.collection.box$20120104131748-789-c82akjt4onjli7qgnbwfz4ltw')
          asset['basepath'].should eq('http://amazon.bucket/realm/app/collection/box/20120104131748-789-c82akjt4onjli7qgnbwfz4ltw')
          asset['sizes'].keys.should eq(%w(100 300 500 1000 5000))
          asset['sizes'].values.should eq(['http://amazon.bucket/realm/app/collection/box/20120104131748-789-c82akjt4onjli7qgnbwfz4ltw/100.jpg', nil, nil, nil, nil])
          asset['original'].should eq('http://amazon.bucket/realm/app/collection/box/20120104131748-789-c82akjt4onjli7qgnbwfz4ltw/original.png')
          asset['aspect'].should eq(0.789)
        end
      end

      describe 'GET /assets/:id' do
        it "returns asset details" do
          get "/assets/realm.app.collection.box"
          last_response.status.should eq(200)
          asset = json_output['image']
          asset['id'].should eq('asset:realm.app.collection.box$20120104131748-789-c82akjt4onjli7qgnbwfz4ltw')
          asset['basepath'].should eq('http://amazon.bucket/realm/app/collection/box/20120104131748-789-c82akjt4onjli7qgnbwfz4ltw')
          asset['sizes'].keys.should eq(%w(100 300 500 1000 5000))
          asset['sizes'].values.should eq(['http://amazon.bucket/realm/app/collection/box/20120104131748-789-c82akjt4onjli7qgnbwfz4ltw/100.jpg', nil, nil, nil, nil])
          asset['original'].should eq('http://amazon.bucket/realm/app/collection/box/20120104131748-789-c82akjt4onjli7qgnbwfz4ltw/original.png')
          asset['aspect'].should eq(0.789)
        end
      end
    end


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
