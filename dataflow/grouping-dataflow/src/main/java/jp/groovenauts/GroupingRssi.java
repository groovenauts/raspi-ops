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
import com.google.cloud.dataflow.sdk.transforms.DoFn.RequiresWindowAccess;
import com.google.cloud.dataflow.sdk.transforms.ParDo;
import com.google.cloud.dataflow.sdk.transforms.PTransform;
import com.google.cloud.dataflow.sdk.transforms.windowing.FixedWindows;
import com.google.cloud.dataflow.sdk.transforms.windowing.Window;
import com.google.cloud.dataflow.sdk.transforms.GroupByKey;
import com.google.cloud.dataflow.sdk.transforms.GroupByKey.GroupAlsoByWindow;
import com.google.cloud.dataflow.sdk.transforms.Max;
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
import java.util.Iterator;

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
  static class DecodeJsonFn extends DoFn<String, KV<String, Double>> {
    @Override
    public void processElement(ProcessContext c) {
      JSONObject json = new JSONObject(c.element());
      if (json.get("type").equals("wifi_rssi")) {
        JSONObject obj = new JSONObject(json.get("attributes").toString());
        Integer tw = obj.getInt("timestamp") / 10;
        String key = String.valueOf(tw) + "%" + obj.get("src_mac") + "_" + obj.get("raspi_mac");
        c.output(KV.of(key, obj.getDouble("rssi")));
      }
    }
  }

  /**
   * A PTransform that converts a PCollection containing lines of text into a PCollection of
   * decoded data
   *
   */
  public static class DecodeJson extends PTransform<PCollection<String>, PCollection<KV<String,Double>>> {
    @Override
    public PCollection<KV<String,Double>> apply(PCollection<String> lines) {

      // Convert lines of text into individual words.
      PCollection<KV<String,Double>> rows = lines.apply(
          ParDo.of(new DecodeJsonFn()));

      return rows;
    }
  }

  public static class PairingMonitorMacFn extends DoFn<KV<String, Double>, KV<String, KV<String, Double>>> {
    @Override
    public void processElement(ProcessContext c) {
      KV<String, Double> row = c.element();
      String[] ary = row.getKey().split("_");
      String newkey = ary[0];
      String raspiMac = ary[1];
      Double rssi = row.getValue();
      c.output(KV.of(newkey, KV.of(raspiMac, rssi)));
    }
  }

  static class EncodeJsonFn extends DoFn<KV<String,Iterable<KV<String, Double>>>, String>
      implements RequiresWindowAccess {
    @Override
    public void processElement(ProcessContext c) {
      KV<String, Iterable<KV<String, Double>>> row = c.element();
      String[] ary = row.getKey().split("%");
      Integer timestamp = Integer.parseInt(ary[0]) * 10;
      String srcMac = ary[1];
      String windowTime = String.valueOf((c.window().maxTimestamp().getMillis()+1)/1000 - WINDOW_SIZE * 60);

      String buf = "{";
      buf += "\"window_time\": " + windowTime + ", ";
      buf += "\"timestamp\": " + String.valueOf(timestamp) + ", ";
      buf += "\"mac_addr\": \"" + srcMac + "\", ";
      buf += "\"rssi\": {";
      Boolean first = true;
      for (Iterator<KV<String, Double>> i = row.getValue().iterator(); i.hasNext();){
        KV<String, Double> e = i.next();
        if (!first) {
          buf += ", ";
        }
        first = false;
        buf += "\"" + e.getKey() + "\":" + String.valueOf(e.getValue());
      }
      buf += "} }";
      c.output(buf);
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

    input.apply(new GroupingRssi.DecodeJson())
         .apply(Window.<KV<String, Double>>into(FixedWindows.of(Duration.standardMinutes(options.getWindowSize()))))
         .apply(Max.<String>doublesPerKey())
         .apply(ParDo.of(new GroupingRssi.PairingMonitorMacFn()))
         .apply(GroupByKey.<String, KV<String, Double>>create())
         .apply(ParDo.of(new GroupingRssi.EncodeJsonFn()))
         .apply(PubsubIO.Write.topic(options.getOutputTopic()));

    PipelineResult result = pipeline.run();
  }
}
