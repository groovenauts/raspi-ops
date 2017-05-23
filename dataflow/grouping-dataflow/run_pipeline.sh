#!/bin/sh

source variables.sh

mvn compile exec:java \
  -Dexec.mainClass=jp.groovenauts.GroupingRssi \
  -Dexec.args="--project=${PROJECT_ID} --stagingLocation=${STAGING} --pubsubTopic=${INPUT_TOPIC} --outputTopic=${OUTPUT_TOPIC} --runner=BlockingDataflowPipelineRunner"
