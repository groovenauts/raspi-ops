# Create Training Data

This tool run BigQuery queries to create training data from `wifi_data` and `wifi_measurement_time` tables.

## How to use.
1. `cd scripts/generate_training_data`
2. `bundle install --path vendor/bundle`
3. Create config.yml and store monitoring device's MAC addresses. See config.yml.example for reference.
3. `bundle exec ruby create_measurement_data.rb --dataset=DATASET_ID`

