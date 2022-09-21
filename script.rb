# frozen_string_literal: true

require 'faraday'
require 'razorpay'
require 'dotenv/load'

Razorpay.setup ENV['RAZORPAY_KEY_ID'], ENV['RAZORPAY_KEY_SECRET']
Razorpay::Subscription.all({ count: 1 })
                      .items.map do |s|
                        puts s.inspect, "created at #{Time.at s['created_at']}"
                      end
