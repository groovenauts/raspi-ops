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
    options = Google::Apis::RequestOptions.default
    options.timeout_sec = 600
    ret = @api.pull_subscription(subscription, Google::Apis::PubsubV1::PullRequest.new(max_messages: 200, return_immediately: false), options: options)
    ret.received_messages || []
  rescue Google::Apis::TransmissionError
    $stderr.puts $!
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
      return nil
    end
    if jobj["error"]
      $stderr.puts "ERR: #{project}/#{model} #{jobj["error"]}"
      return nil
    end
    jobj["predictions"]
  end
end

def main(project, input_subscription, raspi_table, room_classifier, position_inferers, bq_dataset, bq_table, ignore_list, feature_opts)
  $stdout.puts "PubSub:#{input_subscription} -> ML Engine -> BigQuery [#{project}:#{bq_dataset}.#{bq_table}]"
  $stdout.puts feature_opts.inspect
  pubsub = Pubsub.new
  bq = Kura::Client.new

  loop do
    msgs = pubsub.pull(input_subscription)
    $stdout.puts "#{msgs.size} messages pulled."
    next if msgs.empty?
    st = Time.now
    data = msgs.map{|m| JSON.parse(m.message.data) rescue nil }.compact
    instances = data.reject{|m|
      ignore_list.include?(m["mac_addr"])
    }.map do |m|
      if feature_opts[:normalize]
        rssi = raspi_table.map{|n| ((m["rssi"][n] || -100.0) + 100.0) / 50.0 }
      else
        rssi = raspi_table.map{|n| m["rssi"][n] || -100.0 }
      end
      if feature_opts[:combine]
        combine = rssi.combination(2).map{|a, b| b.to_f != 0.0 ? a.to_f / b.to_f : 0.0 }
      else
        combine = []
      end
      {
        "key" => m["window_time"].to_s + "_" + m["timestamp"].to_s + "_" + m["mac_addr"],
        "rssi" => rssi + combine,
      }
    end
    if feature_opts[:normalize]
      default_signal = 0.0
    else
      default_signal = -100.0
    end
    if instances.size > 0
      room_labels = ML.predict(project, room_classifier, instances)
      results = {}
      rooms = {}
      instances.each do|ins|
        r = room_labels.find{|pred| pred["key"] == ins["key"] }
        window_timestamp, timestamp, mac = ins["key"].split("_", 3)
        results[ins["key"]] = {
          "timestamp" => timestamp.to_i,
          "window_timestamp" => window_timestamp.to_i,
          "mac_addr" => mac,
          "room" => r["label"],
          "monitored_ap_count" => ins["rssi"][0, raspi_table.size].count{|sig| sig != default_signal },
        }
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
    end
    pubsub.ack(input_subscription, msgs)
    ed = Time.now
    $stdout.puts "#{ed - st} seconds to process #{msgs.size} messages."
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
  ignore_list = config["ignore_mac_addrs"]
  disable_normalize = config["disable_normalize"]
  disable_combine = config["disable_combine"]
else
  project = ENV["PROJECT"]
  input_subscription = "projects/#{project}/subscriptions/#{ENV["INPUT_SUBSCRIPTION"]}"
  raspi_table = ENV["MAC_ADDRESSES"].split(",")
  room_classifier = ENV["ROOM_CLASSIFIER"]
  position_inferers = ENV["POSITION_INFERERS"].split(",").each_with_object({}){|i, o| room, name = i.split(":", 2); o[room] = name }
  bq_dataset = ENV["BIGQUERY_DATASET"]
  bq_table = ENV["BIGQUERY_TABLE"]
  ignore_list = (ENV["IGNORE_MAC_ADDRESSES"] || "").split(",")
  disable_normalize = ENV["DISABLE_NORMALIZE"]
  disable_combine = ENV["DISABLE_COMBINE"]
end
feature_opts = {
  normalize: not(disable_normalize),
  combine: not(disable_combine),
}

$stdout.sync = true
$stderr.sync = true
main(project, input_subscription, raspi_table, room_classifier, position_inferers, bq_dataset, bq_table, ignore_list, feature_opts)
