require 'spec_helper'
require 'webmock/rspec'

describe TootsieHelper do

  describe "#submit_job" do
    let(:example_job) {
      {
        :type => "image",
        :params => {
          input_url: "http://development.o5.no.s3.amazonaws.com/area51/secret/unit/20120306122011-1498-9et0/original.jpg",
          versions: [
            {
              format: "jpeg",
              width: 100,
              strip_metatadata: true,
              medium: "web",
              target_url: "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/100.jpg?acl=public_read"
            },
            {
              scale: "fit",
              height: 100,
              crop: true,
              format: "jpeg",
              width: 100,
              strip_metatadata: true,
              medium: "web",
              target_url: "s3:development.o5.no/area51/secret/unit/20120306122011-1498-9et0/100sq.jpg?acl=public_read"
            },
          ]
        }
      }
    }

    it "accepts a raw parameter hash and submits a job to tootsie" do
      HTTPClient
        .any_instance
        .should_receive(:post).with("http://tootsie.org/job", example_job.to_json)
        .once
        .and_return(OpenStruct.new(:status_code => 200))
      TootsieHelper.submit_job("http://tootsie.org", example_job)
    end

    it "raises an error if tootsie doesn't return a 2xx status code" do
      HTTPClient
        .any_instance
        .should_receive(:post).with("http://tootsie.org/job", example_job.to_json)
        .once
        .and_return(OpenStruct.new(:status_code => 500))

      lambda { TootsieHelper.submit_job("http://tootsie.org", example_job) }.should raise_error /500/
    end
  end

  describe "#ping" do
    it "pings tootsie" do
      HTTPClient
        .any_instance
        .should_receive(:head).with("http://tootsie.org/status")
        .once
        .and_return(OpenStruct.new(:status_code => 200))

      TootsieHelper.ping("http://tootsie.org")
    end
    it "raises an error if tootsie doesn't return a 2xx status code" do
      HTTPClient
        .any_instance
        .should_receive(:head).with("http://tootsie.org/status")
        .once
        .and_return(OpenStruct.new(:status_code => 404))

      lambda { TootsieHelper.ping("http://tootsie.org") }.should raise_error /404/

    end
  end
end
