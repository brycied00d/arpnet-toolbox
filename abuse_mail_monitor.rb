# Abuse Mail Monitor
#
# Copyright ⓒ 2014 ARP Networks, Inc.
#
# :Author: Garry Dolley
# :Created: 02-16-2014
#
# When we receive complaints of abuse (e.g. SPAM, DoS attack, etc...) and that
# abuse can be identified as originating from a particular IP address, we
# forward the complaint to a special email address monitored by this script.
# This monitor can then lookup the customer / owner of the IP and forward the
# complaint.

require 'mail_monitor'
require 'mail_classifier'
require 'ip_finder'

# Site specific, see config.rb.sample
require 'config'

classifier = MailClassifier::ByClassifier.new(CONFIG[:classifiers])
from       = CONFIG[:from]
body       = CONFIG[:body]

# TODO: :delete_after_find => true, after testing
monitor = MailMonitor.new(60, { :delete_after_find => false }, &CONFIG[:mail])
monitor.go do |msg|
  begin
    @ip = IpFinder.new.find(msg.body.to_s) ||
          IpFinder.new.find(msg.subject, 'server used for an attack:') ||
          IpFinder.new.find(msg.subject, 'service used for an attack:')

    @to = CONFIG[:to].call(@ip)

    mail_class = classifier.classification(msg)

    if mail_class
      # The email that we forward to this processor will be contain two parts:
      #
      #   part 1: the header/body of our email
      #           either empty or containing a tag to identify originating IP
      #   part 2: the original email (abuse complaint)
      #
      # What we want to do is only forward the 2nd part, because it is what is
      # useful.
      orig_email = msg.parts.last

      forwarder = mail_class.forwarder.new(orig_email)
      forwarder.send(@to, from, body, :subj => "FW: #{msg.subject}")

      puts "NOTICE: Classified message as #{mail_class.class}"
      puts "NOTICE: Sent to #{@to} message with subject: #{msg.subject}"
    else
      puts "NOTICE: Could not classify message: #{msg.subject}"
    end
  rescue Exception => e
    $stderr.puts e
  end
end
