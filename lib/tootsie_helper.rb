# A gob of glue to tack the transcoding service Tootsie to ImageBundle
# without too much cruft.

module TootsieHelper
  def self.submit_job(server, job)
    response = HTTPClient.new.post("#{server}/job", job.to_json)
    unless (200...300).include?(response.status_code)
      raise "Tootsie failed with error #{response.status_code} while submitting job #{job.to_json}."
    end
  end

  def self.ping(server)
    response = HTTPClient.new.head("#{server}/status")
    unless (200...300).include? response.status_code
      raise "/status responded with #{response.status_code}"
    end
  end
end
