require 'active_resource'
require 'net/http'
require 'json'
require 'slack-ruby-client'

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

@client = Slack::Web::Client.new

class ExchangeRate < ActiveResource::Base
  self.site = "http://xox.huiseoul.com"
end

def call_yahoo_api
  api_url = URI.parse('http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.xchange%20where%20pair%20in%20(%22USDCNY%22)&format=json&env=store://datatables.org/alltableswithkeys')

  request = Net::HTTP::Get.new(api_url.to_s)
  response = Net::HTTP.start(api_url.host, api_url.port) do |http|
    http.request(request)
  end

  json = JSON.parse(response.body)

  json['query']['results']['rate']
rescue
  @client.chat_postMessage(
    channel: '#k_engineering',
    text: "@here: 환율 정보를 가져오는데 실패하였습니다. #{response}",
    as_user: true
  )

  nil
end

def update
  exchange_rate_info = call_yahoo_api

  return unless exchange_rate_info

  from, to = exchange_rate_info['Name'].split('/')
  rate = exchange_rate_info['Rate']

  insert_exchange_rate(from, to, rate)
  insert_exchange_rate(to, from, (1 / rate.to_f).round(4))
end

def insert_exchange_rate(from, to, rate)
  response = ExchangeRate.create(
    from: from,
    to: to,
    rate: rate
  )

  unless response.id
    @client.chat_postMessage(
      channel: '#k_engineering',
      text: "@here: 환율 업데이트에 실패하였습니다. #{response}",
      as_user: true
    )
  end
end

update
