#!/usr/bin/env ruby

require 'aws-sdk'
require 'pry'
require 'awesome_print'
require 'public_suffix'

# ------------------------------------------------------------------------------
#   Credentials
# ------------------------------------------------------------------------------
# pick up AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY by default from
# environment
Aws.config.update({
  region: 'us-west-2',
})
# ------------------------------------------------------------------------------

def setup_dns(domain, txt_challenge)
  dns_name = PublicSuffix.parse("#{domain}").domain
  route53 = Aws::Route53::Client.new()
  hosted_zone = route53.list_hosted_zones_by_name(
      {dns_name: "#{dns_name}."}).hosted_zones[0]
  changes = []
  changes << {
    action: "UPSERT",
    resource_record_set: {
      name: "_acme-challenge.#{domain}.",
      type: "TXT",
      ttl: 60,
      resource_records: [
        value: "\"#{txt_challenge}\"",
      ],
    },
  }
  resp = route53.change_resource_record_sets({
    hosted_zone_id: hosted_zone.id,
    change_batch: {
      changes: changes,
    },
  })
  ap resp
  resp2 = route53.get_change({id: "#{resp.change_info.id}"})
  ap resp2
  until resp2.change_info.status == "INSYNC"
    sleep 5
    resp2 = route53.get_change({id: "#{resp.change_info.id}"})
    ap resp2
  end
end

def delete_dns(domain, txt_challenge)
  dns_name = PublicSuffix.parse("#{domain}").domain
  route53 = Aws::Route53::Client.new()
  hosted_zone = route53.list_hosted_zones_by_name(
      {dns_name: "#{dns_name}."}).hosted_zones[0]
  changes = []
  changes << {
    action: "DELETE",
    resource_record_set: {
      name: "_acme-challenge.#{domain}.",
      type: "TXT",
      ttl: 60,
      resource_records: [
        value: "\"#{txt_challenge}\"",
      ],
    },
  }
  resp = route53.change_resource_record_sets({
    hosted_zone_id: hosted_zone.id,
    change_batch: {
      changes: changes,
    },
  })
  ap resp
  sleep 10
end

if __FILE__ == $0
  hook_stage = ARGV[0]
  domain = ARGV[1]
  txt_challenge = ARGV[3]

  puts hook_stage
  puts domain
  puts txt_challenge

  if hook_stage == "deploy_challenge"
    setup_dns(domain, txt_challenge)
  elsif hook_stage == "clean_challenge"
    delete_dns(domain, txt_challenge)
  end

end
