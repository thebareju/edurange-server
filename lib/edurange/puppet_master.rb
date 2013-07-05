module Edurange
  class PuppetMaster
    def self.puppetmaster_ip
      # Get external IP using in a way that works in any environment
      debug "Obtaining external ip"
      ip ||= `curl ifconfig.me 2>/dev/null`
    end
    def self.get_our_ssh_key
      # Either returns our current SSH key or generates a new one (and returns it)
      `ssh-keygen -t rsa -f #{ENV['HOME']}/.ssh/id_rsa -N '' -q` unless File.exists?("#{ENV['HOME']}/.ssh/id_rsa")

      file = File.open("#{ENV['HOME']}/.ssh/id_rsa.pub", "rb")
      contents = file.read
    end

    def self.gen_client_ssl_cert(uuid)
      # This generates certificates so puppet can authenticate our client. The certs and such are passed through securely using EC2's API
      # Generates a UUID
      # Creates certificate using puppet
      # Read the cert auth file
      # Read the private key generated for client
      `sudo puppet cert --generate #{uuid}`
      ssl_cert = `sudo cat /var/lib/puppet/ssl/certs/#{uuid}.pem`.chomp
      ca_cert = `sudo cat /var/lib/puppet/ssl/certs/ca.pem`.chomp
      private_key = `sudo cat /var/lib/puppet/ssl/private_keys/#{uuid}.pem`.chomp
      return [ssl_cert, ca_cert, private_key]
    end
    def self.append_to_config(conf)
      File.open("my-user-script.sh", 'a+') do |file|
        file.write(conf)
      end
    end
    def self.write_puppet_conf(instance_id, conf)
      # Creates configuration specific to our newly created host. Stored in /etc/puppet/manifests/#{uuid}.pp
      File.open("#{ENV['HOME']}/edurange/derp.pp", "w") do |file|
        file.write(conf)
      end
      `sudo mv #{ENV['HOME']}/edurange/derp.pp /etc/puppet/manifests/#{instance_id}#{Time.now.to_s.gsub(' ','')}.pp`
    end
    def self.write_shell_config_file(puppetmaster_ip, certs, puppet_conf, facter_facts)
      # This is the startup script run once per instance, generated for each instance.
      # Things done in here include:
      # - Adding puppetmaster's (instructor's) ssh key to instance
      # - Installing puppet
      # - Move clientside puppet.conf file in place
      # - Setting puppet to be the IP of the puppetmaster in /etc/hosts (so ping puppet pings the puppetmaster)
      # - Creating a directory to store facts in (facts later referenced in puppet to install software. Essentially "tagging" our instances)
      # - Reloading puppet
      File.open("my-user-script.sh", 'w') do |file|
        file.write(file_contents)
      end
    end
    def self.generate_puppet_conf(uuid)
      # Generates a puppet.conf file for the client.
      # Certname is the UUID generated by the puppetmaster earlier and passed in,
      # the cert itself authenticates the client ("puppet") with the puppetmaster.
  conf_file = <<conf
[main]
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
factpath=$vardir/lib/facter
templatedir=$confdir/templates
prerun_command=/etc/puppet/etckeeper-commit-pre
postrun_command=/etc/puppet/etckeeper-commit-post
runinterval=60 # run every minute for debug TODO REMOVE
pluginsync=true

[master]
# These are needed when the puppetmaster is run by passenger
# and can safely be removed if webrick is used.
ssl_client_header = SSL_CLIENT_S_DN 
ssl_client_verify_header = SSL_CLIENT_VERIFY

[agent]                                                                                                                                                                                          
certname=#{uuid}
conf
    end
  end
end
