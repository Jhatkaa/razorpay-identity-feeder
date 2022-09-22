# frozen_string_literal: true

require 'json'
require 'faraday'
require 'razorpay'
require 'dotenv/load'

json_body = {
  entity: 'event',
  account_id: ENV.fetch('RAZORPAY_ACCOUNT_ID', nil),
  event: 'subscription.charged',
  contains: %w[subscription payment],
  created_at: Time.now.to_i,
  payload: {}
}

Razorpay.setup ENV.fetch('RAZORPAY_KEY_ID', nil), ENV.fetch('RAZORPAY_KEY_SECRET', nil)

12.times do |skip|
  items = Razorpay::Subscription.all({ count: 100, skip: skip * 100 }).items

  break if items.length.zero?

  items.map do |s|
    next if s['status'].nil? || s['status'] == 'created'

    puts "#{s['id']}, #{s['status']} created at #{Time.at s['created_at']}"

    $email = nil
    $mobile = nil

    invoices = Razorpay::Invoice.all({ subscription_id: s['id'], count: 100 })
    invoices.items.select { |i| i['status'] == 'paid' }.map do |i|
      payment = Razorpay::Payment.fetch i['payment_id']

      $email = payment.email unless payment.email == 'void@razorpay.com'
      $mobile = payment.contact unless payment.contact == '+919999999999'

      json_body[:payload]['subscription'] = { entity: s }
      json_body[:payload]['payment'] = { entity: payment }

      hashed = JSON.parse(json_body.to_json)
      hashed['payload']['payment']['entity']['email'] = $email
      hashed['payload']['payment']['entity']['contact'] = $mobile

      puts "\t- #{payment.id}, #{payment.status} from " \
           "#{hashed['payload']['payment']['entity']['email']} " \
           "#{hashed['payload']['payment']['entity']['contact']}"

      response = Faraday.post("#{ENV.fetch('IDENTITY_WEBHOOK_ENDPOINT', nil)}?api_token=" \
                              "#{ENV.fetch('IDENTITY_API_TOKEN', nil)}",
                              hashed.to_json, 'Content-Type': 'application/json')

      puts "\t  created at #{Time.at(payment.created_at)}  --  #{response.status}"
    end
  end
end
