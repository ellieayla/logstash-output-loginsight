# encoding: utf-8
# Copyright © 2017 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

require "logstash/outputs/http"

# This output plugin is used to send Events to a VMware vRealize Log Insight cluster,
# preserving existing fields on Events as key=value fields. Timestamps are transmitted
# as milliseconds-since-epoch UTC.

# output { loginsight { host => ["10.11.12.13"] } }

class LogStash::Outputs::Loginsight < LogStash::Outputs::Http

  config_name "loginsight"


  config :host, :validate => :string, :required => true
  config :port, :validate => :number, :default => 9543
  config :proto, :validate => :string, :default => 'https'
  config :uuid, :validate => :string, :default => nil

  config :verify, :default => true, :deprecated => 'Deprecated alias for "ssl_certificate_validation". Insecure. For self-signed certs, use openssl s_client to save server\'s certificate to a PEM-formatted file. Then pass the filename in "cacert" option.'
  config :ca_file, :validate => :string, :default => nil, :deprecated => 'Deprecated alias for "cacert", specify path to PEM-formatted file.'

  config :flush_size, :validate => :number, :default => 1, :obsolete => 'Has no effect. Events are sent without delay.'
  config :idle_flush_time, :validate => :number, :default => 1, :obsolete => 'Has no effect. Events are sent without delay.'

  # Fields that will be renamed or dropped.
  config :adjusted_fields, :validate => :hash, :default => {
      'hostname' => 'host',  # unlikely to be present, preserve anyway
      'host' => 'hostname',  # desired change
      '@version' => nil,  # drop
      '@timestamp' => nil,  # drop, already mapped to "timestamp" in event_hash
      'message' => nil,  # drop, already mapped to "text" in event_hash
      'timestamp' => 'timestamp_',  # Log Insight will refuse events with a "timestamp" field.
  }

  config :url, :validate => :string, :default => nil, :deprecated => 'Use "host", "port", "proto" and "uuid" instead.'


  # Remove configuration options from superclass that don't make sense for this plugin.
  @config.delete('http_method')  # CFAPI is post-only
  @config.delete('format')
  @config.delete('message')

  public
  def register

    if @cacert.nil?
      @cacert = @ca_file
    end

    unless @verify.nil?
      @ssl_certificate_validation = @verify
    end

    # Hard-wired options
    @http_method = 'post'
    @format = 'json'
    @content_type = 'application/json'

    @uuid ||= ( @id or 0 )  # Default UUID
    @logger.debug("Starting up agent #{@uuid}")

    if @url.nil?
      @url = "#{@proto}://#{@host}:#{@port}/api/v1/events/ingest/#{@uuid}"
    end

    super

  end # def register

  # override function from parent class, Http, removing other format modes
  def event_body(event)
    LogStash::Json.dump(cfapi([event]))
  end

  def timestamp_in_milliseconds(timestamp)
    (timestamp.to_f * 1000).to_i
  end

  # Frame the events in the hash-array structure required by Log Insight
  def cfapi(events)
    messages = []

    # For each event
    events.each do |event|
      # Create an outbound event; this can be serialized to json and sent
      event_hash = {
        'timestamp' => timestamp_in_milliseconds(event.get('@timestamp')),
        'text' => (event.get('message') or ''),
      }

      # Map fields from the event to the desired form
      event_hash['fields'] = merge_hash(event.to_hash)
        .reject { |key,value| @adjusted_fields.has_key?(key) and @adjusted_fields[key] == nil }  # drop banned fields
        .map {|k,v| [ @adjusted_fields.has_key?(k) ? @adjusted_fields[k] : k,v] }  # rename fields
        .map {|k,v| { 'name' => (safefield(k)), 'content' => v } }  # Convert a hashmap {k=>v, k2=>v2} to a list [{name=>k, content=>v}, {name=>k2, content=>v2}]

        messages.push(event_hash)
    end # events.each do

    { 'events' => messages }  # Framing required by CFAPI.
  end # def cfapi

  # Return a copy of the fieldname with non-alphanumeric characters removed.
  def safefield(fieldname)
    fieldname.gsub(/[^a-zA-Z0-9_]/, '')  # TODO: Correct pattern for a valid fieldname. Must deny leading numbers.
  end

  # Recursively merge a nested dictionary into a flat dictionary with dotted keys.
  def merge_hash(hash, prelude = nil)
    hash.reduce({}) do |acc, kv|
      k, v = kv
      generated_key = prelude ? "#{prelude}_#{k}" : k.to_s
      #puts("Generated key #{generated_key}")
      if v.is_a?(Hash)
        acc.merge!(merge_hash(v, generated_key))
      elsif v.is_a?(Array)
        acc[generated_key] = v.to_s
      else
        acc[generated_key] = v
      end
      acc
    end
  end

end # class LogStash::Outputs::Loginsight
