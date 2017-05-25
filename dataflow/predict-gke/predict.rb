# coding: utf-8

require "yaml"
require "kura"
require "google/apis/pubsub_v1"

class Pubsub
  def initialize
    # use default credential
    @api = Google::Apis::PubsubV1::PubsubService.new
    @api.authorization = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    @api.authorization.fetch_access_token!
  end

  def pull(subscription)
    ret = @api.pull_subscription(subscription, Google::Apis::PubsubV1::PullRequest.new(max_messages: 1000, return_immediately: false))
    ret.received_messages || []
  rescue Google::Apis::TransmissionError
    $stderr.puts $!
    $stderr.flush
    []
  end

  def ack(subscription, msgs)
    msgs = [msg] unless msgs.is_a?(Array)
    return if msgs.empty?
    ack_ids = msgs.map(&:ack_id)
    @api.acknowledge_subscription(subscription, Google::Apis::PubsubV1::AcknowledgeRequest.new(ack_ids: ack_ids))
  end
end

module ML
  module_function
  def predict(project, model, instances)
    auth = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    auth.fetch_access_token!
    access_token =  auth.access_token
    uri = URI("https://ml.googleapis.com/v1/projects/#{project}/models/#{model}:predict")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["content-type"] = "application/json"
    req["Authorization"] = "Bearer #{access_token}"
    req.body = JSON.generate({ "instances" => instances })
    res = http.request(req)
    begin
      jobj = JSON.parse(res.body)
    rescue
      $stderr.puts "ERR: #{$!}"
      $stderr.flush
      return nil
    end
    if jobj["error"]
      $stderr.puts "ERR: #{project}/#{model} #{jobj["error"]}"
      $stderr.flush
      return nil
    end
    jobj["predictions"]
  end
end

def main(project, input_subscription, raspi_table, room_classifier, position_inferers, bq_dataset, bq_table)
  pubsub = Pubsub.new
  bq = Kura::Client.new

  loop do
    msgs = pubsub.pull(input_subscription)
    $stdout.puts "#{msgs.size} messages pulled."
    $stdout.flush
    next if msgs.empty?
    st = Time.now
    data = msgs.map{|m| JSON.parse(m.message.data) rescue nil }.compact
    instances = data.map do |m|
      { "key" => m["timestamp"].to_s + "_" + m["mac_addr"], "rssi" => raspi_table.map{|n| m["rssi"][n] || -100.0 } }
    end
    room_labels = ML.predict(project, room_classifier, instances)
    results = {}
    rooms = {}
    instances.each do|ins|
      r = room_labels.find{|pred| pred["key"] == ins["key"] }
      timestamp, mac = ins["key"].split("_", 2)
      results[ins["key"]] = { "timestamp" => timestamp.to_i, "mac_addr" => mac, "room" => r["label"] }
      if position_inferers.include?(r["label"].to_s)
        rooms[r["label"]] ||= []
        rooms[r["label"]] << ins
      end
    end
    rooms.each do |room_no, ins|
      positions = ML.predict(project, position_inferers[room_no.to_s], ins)
      positions.each do |pos|
        results[pos["key"]]["x"] = pos["output"][0]
        results[pos["key"]]["y"] = pos["output"][1]
      end
    end
    bq.insert_tabledata(bq_dataset, bq_table, results.values)
    pubsub.ack(input_subscription, msgs)
    ed = Time.now
    $stdout.puts "#{ed - st} seconds to process #{msgs.size} messages."
    $stdout.flush
  end
end

config, = ARGV

if config
  config = YAML.load(File.read(config))
  project = config["project"]
  input_subscription = "projects/#{project}/subscriptions/#{config["input_subscription"]}"
  raspi_table = config["mac_addresses"]
  room_classifier = config["room_classifier"]
  position_inferers = config["position_inferers"]
  bq_dataset = config["bigquery_dataset"]
  bq_table = config["bigquery_table"]
else
  project = ENV["PROJECT"]
  input_subscription = "projects/#{project}/subscriptions/#{ENV["INPUT_SUBSCRIPTION"]}"
  raspi_table = ENV["MAC_ADDRESSES"].split(",")
  room_classifier = ENV["ROOM_CLASSIFIER"]
  position_inferers = ENV["POSITION_INFERERS"].split(",").each_with_object({}){|i, o| room, name = i.split(":", 2); o[room] = name }
  bq_dataset = ENV["BIGQUERY_DATASET"]
  bq_table = ENV["BIGQUERY_TABLE"]
end

main(project, input_subscription, raspi_table, room_classifier, position_inferers, bq_dataset, bq_table)
