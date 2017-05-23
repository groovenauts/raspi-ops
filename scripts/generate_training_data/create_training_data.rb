
require "optparse"
require "yaml"
require "kura"

config = {
  name: "demo",
}
OptionParser.new do |opt|
  opt.on("--project PROJECT_ID", "specify GCP project id") do |str|
    config[:project_id] = str
  end
  opt.on("--dataset DATASET", "specify BigQuery Dataset ID") do |str|
    config[:dataset] = str
  end
  opt.on("--name NAME", "specify the name of training.") do |str|
    config[:name] = str
  end
  opt.on("--room ROOM_NUMBER", "specify room number for generating positional data.", Integer) do |num|
    config[:room] = num
  end
  opt.parse!
  if ARGV[0]
    config_file = ARGV[0]
  else
    config_file = "./config.yml"
  end
  d = YAML.load(File.read(config_file))
  config[:mac_addresses] = d["mac_addresses"]
end

project_id = config[:project_id]
dataset = config[:dataset]
mac_addresses = config[:mac_addresses]
puts "Project ID: #{project_id}"
puts "Dataset ID: #{dataset}"
puts "Monitoring Mac Addresses: #{mac_addresses.count}"

client = Kura::Client.new(default_project_id: project_id)

if config[:room]
  room_query = "#standardSQL\n"
  room_query << "SELECT\n"
  mac_addresses.size.times do |i|
    num = i + 1
    room_query << "  IFNULL(r#{num}, -100) AS r#{num},\n"
  end
  room_query << "  x, y\n"
  room_query << "FROM `#{project_id}.#{dataset}.measurement_data`\n"
  room_query << "WHERE room = #{config[:room]}"
  puts room_query
  j = client.query(room_query, priority: "INTERACTIVE", use_legacy_sql: false, allow_large_results: nil, wait: 300)
  dest = j.configuration.query.destination_table
  total = []
  page_token = nil
  while true
    data = client.list_tabledata(dest.dataset_id, dest.table_id, project_id: dest.project_id, page_token: page_token, max_result: 1000)
    data[:rows].each do |r|
      total << [ *mac_addresses.size.times.map{|i| r["r#{i+1}"] }, r["x"], r["y"] ]
    end
    page_token = data[:next_token]
    break if page_token.nil?
  end
else
  room_query = "#standardSQL\n"
  room_query << "SELECT\n"
  mac_addresses.size.times do |i|
    num = i + 1
    room_query << "  IFNULL(r#{num}, -100) AS r#{num},\n"
  end
  room_query << "  room\n"
  room_query << "FROM `#{project_id}.#{dataset}.measurement_data`"
  puts room_query
  j = client.query(room_query, priority: "INTERACTIVE", use_legacy_sql: false, allow_large_results: nil, wait: 300)
  dest = j.configuration.query.destination_table
  total = []
  page_token = nil
  while true
    data = client.list_tabledata(dest.dataset_id, dest.table_id, project_id: dest.project_id, page_token: page_token, max_result: 1000)
    data[:rows].each do |r|
      total << [ *mac_addresses.size.times.map{|i| r["r#{i+1}"] }, r["room"] ]
    end
    page_token = data[:next_token]
    break if page_token.nil?
  end
end
training_size = (total.size * 0.8).floor
test_size = total.size - training_size
puts "Total #{total.size} rows: divide into #{training_size}:#{test_size} csv." 
total = total.shuffle
open("#{config[:name]}-training.csv", "w"){|f| f.puts total[0, training_size].map{|l| l.join(",") } }
open("#{config[:name]}-test.csv", "w"){|f| f.puts total[training_size..-1].map{|l| l.join(",") } }

