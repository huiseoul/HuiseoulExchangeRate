require 'active_resource'
require 'net/http'
require 'json'
require 'slack-ruby-client'

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

@client = Slack::Web::Client.new

class Currency < ActiveResource::Base
  self.site = "http://localhost:3000"
end

def call_yahoo_api
  api_url = URI.parse('http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20in%20(%22USDCNY%22)&format=json&env=store://datatables.org/alltableswithkeys&callback=')

  request = Net::HTTP::Get.new(api_url.to_s)
  response = Net::HTTP.start(api_url.host, api_url.port) do |http|
    http.request(request)
  end

  json = JSON.parse(response.body)

  json['query']['results']['rate']
rescue
  @client.chat_postMessage(
    channel: '#z_huibot',
    text: "@here: 환율 정보를 가져오는데 실패하였습니다. #{response}",
    as_user: true
  )

  nil
end

def insert_currency
  currency_info = call_yahoo_api

  return unless currency_info

  response = Currency.create(
    name: currency_info['Name'],
    rate: currency_info['Rate']
  )

  if response.id
    @client.chat_postMessage(
      channel: '#z_huibot',
      text: "환율이 업데이트 되었습니다. #{response.name}: #{response.rate}",
      as_user: true
    )
  else
    @client.chat_postMessage(
      channel: '#z_huibot',
      text: "@here: 환율 업데이트에 실패하였습니다. #{response}",
      as_user: true
    )
  end
end

insert_currency
