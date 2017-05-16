# encoding: utf-8
# Copyright © 2017 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/loginsight"
require "logstash/codecs/plain"
require "logstash/event"

describe LogStash::Outputs::Loginsight do
  
  let(:epoch123) { "1970-01-01T00:00:00.123Z" }
  let(:port) { 9543 }
  let(:server) { subject.socket }
  let(:sample_event) { LogStash::Event.new }

  describe "safefield" do
    let(:safefield) { LogStash::Outputs::Loginsight.new("host" => "localhost").send(:safefield, proposed) }
    context "a simple name" do
      let(:proposed) { "simple" }
      it "should do nothing" do
        expect(safefield).to eql("simple")
      end
    end

    context "special characters" do
      let(:proposed) { "a!_@{$%^&*()}[]|\\/.,;:'`~b" }
      it "should be stripped" do
        expect(safefield).to eql("a_b")
      end
    end

    context "a name with spaces" do
      let(:proposed) { "a name with spaces" }
      it "should strip spaces" do
        expect(safefield).to eql("anamewithspaces")
      end
    end

    context "a name starting with a @" do
      let(:proposed) { "@abc" }
      it "should strip the @" do
        expect(safefield).to eql("abc")
      end
    end
    
    # TODO: Test for a fieldname starting with a number or underscore
  end

  describe "dotify" do
    let(:event) { LogStash::Event.new() }
    let(:merged) { LogStash::Outputs::Loginsight.new("host" => "localhost").send(:merge_hash, hash) }

    context "a simple hash" do
      let(:hash) { {:a => 2, 5 => 4} }
      it "should do nothing more than stringify the keys" do
        expect(merged).to eql("a" => 2, "5" => 4)
      end
    end

    context "a complex hash" do
      let(:hash) { {:a => 2, :b => {:c => 3, :d => 4, :e => {:f => 5}}} }
      it "should dottify correctly" do
        expect(merged).to eql({"a" => 2, "b_c" => 3, "b_d" => 4, "b_e_f" => 5})
      end
    end
  end

  describe "timestamp" do
    let(:t_in_ms) { LogStash::Outputs::Loginsight.new("host" => "localhost").send(:timestamp_in_milliseconds, ts) }
    context "0.123Z in milliseconds" do
      let(:ts) { LogStash::Timestamp.new("1970-01-01T00:00:00.123Z") }
      it "should be 123" do
        expect(t_in_ms).to eql(123)
      end
    end
  end

  describe "simple cfapi with" do
    let(:cfapi) { LogStash::Outputs::Loginsight.new("host" => "localhost").send(:cfapi, events) }

    context "no events" do
      let(:events) { [] }
      it "should produce an empty list of events" do
        expect(cfapi).to eql({"events" => []})
      end
    end

    context "two events with no content" do
      let(:events) { [LogStash::Event.new, LogStash::Event.new] }
      it "should have an events key with a list of two" do
        expect(cfapi).to have_key("events")
        expect((cfapi)["events"].size).to eq(2)
      end
    end

    context "an event with no content" do
      let(:events) { [LogStash::Event.new] }
      it "should have an events key with a non-empty list" do
        expect(cfapi).to have_key("events")
        expect((cfapi)["events"]).not_to be_empty
      end
    end

    context "an empty event" do
      let(:events) { [LogStash::Event.new] }
      let(:subject) { (cfapi)["events"][0] }
      it "should have a timestamp" do
        expect(subject).to have_key("timestamp")
        expect(subject["timestamp"]).not_to be_zero
      end
      it "should have an empty text string" do
        expect(subject).to have_key("text")
        expect(subject["text"]).to match("")
      end
      it "should have an empty field list" do
        expect(subject).to have_key("fields")
        expect(subject["fields"]).to be_kind_of(Array)
        expect(subject["fields"]).to eql([])
      end
    end
  end  # simple cfapi with

  describe "complex cfapi with" do
    let(:cfapi) { LogStash::Outputs::Loginsight.new("host" => "localhost").send(:cfapi, events) }

    context "only fields" do
      let(:events) { [LogStash::Event.new("@timestamp"=>epoch123, "@version"=>1, "bar"=>"baz")] }
      it "should produce a populated dict" do
        expect(cfapi).to eql({"events" => [{"timestamp"=>123, "text"=>"", "fields"=>[{"name"=>"bar", "content"=>"baz"}]}]})
      end
    end

    context "a populated event" do
      let(:events) { [LogStash::Event.new("@timestamp"=>epoch123, "@version"=>1, "message"=>"foo", "bar"=>"baz")] }
      it "should produce a populated dict" do
        expect(cfapi).to eql({"events" => [{"timestamp"=>123, "text"=>"foo", "fields"=>[{"name"=>"bar", "content"=>"baz"}]}]})
      end
    end

    context "a nested keyed event" do
      let(:events) { [LogStash::Event.new("@timestamp"=>epoch123, "@version"=>1, "message"=>"foo", "bar"=>{"baz"=>"awesome"})] }
      it "should produce an awesome dict" do
        expect(cfapi).to eql({"events" => [{"timestamp"=>123, "text"=>"foo", "fields"=>[{"name"=>"bar_baz", "content"=>"awesome"}]}]})
      end
    end
  end  # complex cfapi with

end
