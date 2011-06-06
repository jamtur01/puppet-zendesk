require 'puppet'
require 'json'
require 'yaml'

begin
  require 'httparty'
rescue LoadError => e
  Puppet.info "You need the `httparty` gem to use the Zendesk report"
end

Puppet::Reports.register_report(:zendesk) do

  configfile = File.join([File.dirname(Puppet.settings[:config]), "zendesk.yaml"])
  raise(Puppet::ParseError, "zendesk report config file #{configfile} not readable") unless File.exist?(configfile)
  config = YAML.load_file(configfile)
  ZENDESK_SITE = config[:zendesk_site]
  ZENDESK_USER = config[:zendesk_user]
  ZENDESK_PASS = config[:zendesk_password]

  desc <<-DESC
  Send notification of failed reports to Zendesk and open new tickets.
  DESC

  def process
    if self.status == 'failed'
      Puppet.debug "Creating Zendesk ticket for failed run on #{self.host}."
      payload = {}
      output = []
      self.logs.each do |log|
        output << log
      end
      payload = { :ticket => { :subject => "Puppet run for #{self.host} #{self.status} at #{Time.now.asctime}",
                  :description => output.join("\n"), :priority_id => 0, :requester_email => "#{ZENDESK_USER}" } }
      response = HTTParty.post("#{ZENDESK_SITE}tickets.json", :basic_auth => {:username=>"#{ZENDESK_USER}", :password=> "#{ZENDESK_PASS}"}, :body => payload )
      Puppet.err "Response code: #{response.code} - #{response.body}" unless response.code == 201
    end
  end
end
