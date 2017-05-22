/*
 * Copyright (C) 2015 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */

package jp.groovenauts;

import com.google.api.services.bigquery.model.TableFieldSchema;
import com.google.api.services.bigquery.model.TableReference;
import com.google.api.services.bigquery.model.TableRow;
import com.google.api.services.bigquery.model.TableSchema;
import com.google.cloud.dataflow.sdk.Pipeline;
import com.google.cloud.dataflow.sdk.PipelineResult;
import com.google.cloud.dataflow.sdk.io.BigQueryIO;
import com.google.cloud.dataflow.sdk.io.PubsubIO;
import com.google.cloud.dataflow.sdk.io.TextIO;
import com.google.cloud.dataflow.sdk.options.Default;
import com.google.cloud.dataflow.sdk.options.Description;
import com.google.cloud.dataflow.sdk.options.DataflowPipelineOptions;
import com.google.cloud.dataflow.sdk.options.PipelineOptions;
import com.google.cloud.dataflow.sdk.options.PipelineOptionsFactory;
import com.google.cloud.dataflow.sdk.transforms.DoFn;
import com.google.cloud.dataflow.sdk.transforms.ParDo;
import com.google.cloud.dataflow.sdk.transforms.PTransform;
import com.google.cloud.dataflow.sdk.transforms.windowing.FixedWindows;
import com.google.cloud.dataflow.sdk.transforms.windowing.Window;
import com.google.cloud.dataflow.sdk.values.KV;
import com.google.cloud.dataflow.sdk.values.PCollection;

import org.joda.time.Duration;
import org.joda.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.json.*;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;


/**
 * <p>To execute this pipeline locally, specify general pipeline configuration:
 * <pre>{@code
 *   --project=YOUR_PROJECT_ID
 * }
 * </pre>
 *
 * <p>To execute this pipeline using the Dataflow service, specify pipeline configuration:
 * <pre>{@code
 *   --project=YOUR_PROJECT_ID
 *   --stagingLocation=gs://YOUR_STAGING_DIRECTORY
 *   --runner=BlockingDataflowPipelineRunner
 * }
 * </pre>
 *
 * <p>By default, the pipeline will do fixed windowing, on 3-minute windows.  You can
 * change this interval by setting the {@code --windowSize} parameter, e.g. {@code --windowSize=10}
 * for 10-minute windows.
 */
public class GroupingRssi {
    private static final Logger LOG = LoggerFactory.getLogger(GroupingRssi.class);
    static final int WINDOW_SIZE = 3;  // Default window duration in minutes

  /**
   * Concept #2: You can make your pipeline code less verbose by defining your DoFns statically out-
   * of-line. This DoFn decode JSON into rssi data; we pass it to a ParDo in the
   * pipeline.
   */
  static class DecodeJsonFn extends DoFn<String, KV<String, TableRow>> {
    @Override
    public void processElement(ProcessContext c) {
      JSONObject json = new JSONObject(c.element());
      if (json.get("type").equals("wifi_rssi")) {
        JSONObject obj = new JSONObject(json.get("attributes").toString());
        TableRow row = new TableRow()
          .set("timestamp", obj.get("timestamp"))
          .set("src_mac", obj.get("src_mac"))
          .set("raspi_mac", obj.get("raspi_mac"))
          .set("rssi", obj.get("rssi"));
        Integer tw = obj.getInt("timestamp") / 10;
        String key = String.valueOf(tw) + "_" + obj.get("src_mac") + "_" + obj.get("raspi_mac");
        c.output(KV.of(key, row));
      }
    }
  }

  /**
   * A PTransform that converts a PCollection containing lines of text into a PCollection of
   * decoded data
   *
   */
  public static class DecodeJson extends PTransform<PCollection<String>, PCollection<KV<String,TableRow>>> {
    @Override
    public PCollection<KV<String,TableRow>> apply(PCollection<String> lines) {

      // Convert lines of text into individual words.
      PCollection<KV<String,TableRow>> rows = lines.apply(
          ParDo.of(new DecodeJsonFn()));

      return rows;
    }
  }

  static class EncodeJsonFn extends DoFn<KV<String,TableRow>, String> {
    @Override
    public void processElement(ProcessContext c) {
      KV<String, TableRow> row = c.element();
      c.output(row.getKey() + " " + String.valueOf(row.getValue().get("rssi")));
    }
  }

  public static class EncodeJson extends PTransform<PCollection<KV<String,TableRow>>, PCollection<String>> {
    @Override
    public PCollection<String> apply(PCollection<KV<String,TableRow>> rows) {

      // Convert lines of text into individual words.
      PCollection<String> words = rows.apply(
          ParDo.of(new EncodeJsonFn()));

      return words;
    }
  }

  public interface Options extends PipelineOptions, DataflowPipelineOptions {
    @Description("Fixed window duration, in minutes")
    @Default.Integer(WINDOW_SIZE)
    Integer getWindowSize();
    void setWindowSize(Integer value);

    @Description("Pub/Sub topic")
    @Default.String("projects/PROJECT-ID/topics/streamingInTopic")
    String getPubsubTopic();
    void setPubsubTopic(String topic);

    @Description("Output Topic Name")
    @Default.String("projects/PROJECT-ID/topics/streamingOutTopic")
    String getOutputTopic();
    void setOutputTopic(String value);
  }

  public static void main(String[] args) throws IOException {
    Options options = PipelineOptionsFactory.fromArgs(args).withValidation().as(Options.class);

    options.setStreaming(true);

    Pipeline pipeline = Pipeline.create(options);

    /**
     * Concept #1: the Dataflow SDK lets us run the same pipeline with either a bounded or
     * unbounded input source.
     */
    PCollection<String> input;
    LOG.info("Reading from PubSub.");
    /**
     * Concept #3: Read from the PubSub topic. A topic will be created if it wasn't
     * specified as an argument. The data elements' timestamps will come from the pubsub
     * injection.
     */
    input = pipeline
        .apply(PubsubIO.Read.topic(options.getPubsubTopic()));

    /**
     * Concept #4: Window into fixed windows. The fixed window size for this example defaults to 1
     * minute (you can change this with a command-line option). See the documentation for more
     * information on how fixed windows work, and for information on the other types of windowing
     * available (e.g., sliding windows).
     */
    PCollection<String> windowedJson = input
      .apply(Window.<String>into(
        FixedWindows.of(Duration.standardMinutes(options.getWindowSize()))));

    PCollection<KV<String, TableRow>> data = windowedJson.apply(new GroupingRssi.DecodeJson());

    data.apply(new GroupingRssi.EncodeJson())
        .apply(PubsubIO.Write.topic(options.getOutputTopic()));

    PipelineResult result = pipeline.run();
  }
}
