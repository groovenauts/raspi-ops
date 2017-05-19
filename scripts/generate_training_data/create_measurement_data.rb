
require "optparse"
require "yaml"
require "kura"

config = {
  project_id: "blocks-next-2017",
  interval: 10,
}
OptionParser.new do |opt|
  opt.on("--project PROJECT_ID", "specify GCP project id") do |str|
    config[:project_id] = str
  end
  opt.on("--dataset DATASET", "specify BigQuery Dataset ID") do |str|
    config[:dataset] = str
  end
  opt.on("--interval INTERVAL", "specify interval in seconds", Integer) do |int|
    confing[:interval] = int
  end
  opt.parse!
  config_file, = ARGV
  d = YAML.load(File.read(config_file))
  config[:mac_addresses] = d["mac_addresses"]
end

project_id = config[:project_id]
dataset = config[:dataset]
mac_addresses = config[:mac_addresses]
puts "Project ID: #{project_id}"
puts "Dataset ID: #{dataset}"
puts "Monitoring Mac Addresses:"
config[:mac_addresses].each{|addr| puts "  " + addr }

client = Kura::Client.new(default_project_id: project_id)

measurement_per_raspi_query = <<-EOQ
SELECT timestamp, w.src_mac AS src_mac, raspi_mac, FLOAT(rssi) AS rssi, room, x, y
FROM [#{project_id}:#{dataset}.wifi_measurement_time] AS t
CROSS JOIN
(SELECT timestamp, raspi_mac, _t.src_mac AS src_mac, rssi
 FROM [#{project_id}:#{dataset}.wifi_measurement_time] AS _t
 LEFT JOIN
 [#{project_id}:#{dataset}.wifi_data] AS _w
 ON _t.src_mac = _w.src_mac
) AS w
WHERE t.start_time <= w.timestamp AND t.finish_time >= w.timestamp AND w.src_mac = t.src_mac
EOQ
puts "Run query."
puts measurement_per_raspi_query

client.query(measurement_per_raspi_query, dataset_id: dataset, table_id: "measurement_data_per_raspi",
             allow_large_results: true,
             priority: "INTERACTIVE",
             mode: :truncate,
             wait: 300)

table = client.table(dataset, "measurement_data_per_raspi")
puts "-> #{table.id} (#{table.num_rows} rows)"

measurement_data_query = <<-EOQ
SELECT
  t, #{mac_addresses.size.times.map{|i| "MAX(r#{i+1}) as r#{i+1}" }.join(", ")}, room, x, y
FROM
#{mac_addresses.map.with_index{|addr, i|
  q = "  (SELECT INTEGER(timestamp/#{config[:interval]}) AS t, "
  mac_addresses.size.times.each{|j|
    if i == j
      q += "MAX(rssi) AS r#{j+1}, "
    else
      q += "NULL AS r#{j+1}, "
    end
  }
  q += "room, x, y\n"
  q += "FROM [#{project_id}:#{dataset}.measurement_data_per_raspi] WHERE raspi_mac = \"#{addr}\" GROUP BY t, room, x, y)"
  q
}.join(",\n")
}
GROUP BY t, room, x, y
ORDER BY room, x, y, t
EOQ

puts "Run query."
puts measurement_data_query
client.query(measurement_data_query, dataset_id: dataset, table_id: "measurement_data",
             allow_large_results: true,
             priority: "INTERACTIVE",
             mode: :truncate,
             wait: 300)

table = client.table(dataset, "measurement_data")
puts "-> #{table.id} (#{table.num_rows} rows)"
