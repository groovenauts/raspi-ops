# Create Training Data

## create_measurement_data.rb

This tool run BigQuery queries to create training data from `wifi_data` and `wifi_measurement_time` tables.

### Preconditions

- Monitored mac addresses are stored in `wifi_data` table in certain dataset of BigQuery.
- Measurement time data are stored in `measurement_time` table in the same dataset of BigQuery.

### How to use.

1. `cd scripts/generate_training_data`
2. `bundle install --path vendor/bundle`
3. Create config.yml and store monitoring device's MAC addresses. See config.yml.example for reference.
4. `bundle exec ruby create_measurement_data.rb --project=PROJECT-ID --dataset=DATASET_ID`

## create_training_data.rb

This tool create xxx-training.csv and xxx-test.csv to be used in BLOCKS ML Board.

## How to use.

1. `cd scripts/generate_training_data`
2. `bundle install --path vendor/bundle`
3. `bundle exec ruby create_training_data.rb --project=PROJECT-ID --dataset=DATASET_ID --name=PREFIX` to create room classifier's training data.
4. `bundle exec ruby create_training_data.rb --project=PROJECT-ID --dataset=DATASET_ID --name=PREFIX --room=ROOM_NO` to create position predictor's training data.


