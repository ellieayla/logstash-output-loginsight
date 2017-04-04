# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "stud/buffer"
require "manticore"
#require "logstash/agent"

# An output plugin that sends events to a VMware vRealize Log Insight cluster.
class LogStash::Outputs::Loginsight < LogStash::Outputs::Base
  include Stud::Buffer

  config_name "loginsight"

  config :host, :validate => :string, :required => true
  config :port, :validate => :number, :default => 9543
  config :proto, :validate => :string, :default => "https"
  config :uuid, :validate => :string, :default => nil
  config :verify, :validate => :boolean, :default => true
  config :ca_file, :validate => :string, :default => nil

  config :flush_size, :validate => :number, :default => 100
  config :idle_flush_time, :validate => :number, :default => 1

  # Fields that will be renamed or dropped.
  config :adjusted_fields, :validate => :hash, :default => {
    "hostname" => "host",  # unlikely to be present, preserve anyway
    "host" => "hostname",  # desired change
    "@version" => nil,  # drop
    "@timestamp" => nil,  # drop, already mapped to "timestamp" in event_hash
    "message" => nil,  # drop, already mapped to "text" in event_hash
  }

  concurrency :single

  public
  def register
    @uuid ||= ( @id or 0 )  # Default UUID
    @logger.debug("Starting up agent #{@uuid}")
    @url = "#{@proto}://#{@host}:#{@port}/api/v1/events/ingest/#{@uuid}"

    if  @proto == "https"
      @client = Manticore::Client.new(headers: {"Content-Type" => "application/json"} , ssl:{ verify: @verify , ca_file:  @ca_file } )
    else
      @client = Manticore::Client.new(headers: {"Content-Type" => "application/json"} )
    end

    @logger.debug("Client", :client => @client)

    buffer_initialize(
      :max_items => @flush_size,
      :max_interval => @idle_flush_time,
      :logger => @logger
    )
  end # def register

  public
  def receive(event)
    @logger.debug("Event received", :event => event)
    buffer_receive(event)
  end # def receive

  public
  def flush(events, database, teardown = false)
    @logger.debug? and @logger.debug("Flushing #{events.size} events - Teardown? #{teardown}")
    
    post(cfapi(events))
  end

  def timestamp_in_milliseconds(timestamp)
    return (timestamp.to_f * 1000).to_i
  end

  # Frame the events in the hash-array structure required by Log Insight
  def cfapi(events)
    messages = []

    # For each event
    events.each do |event|
      # Create an outbound event; this can be serialized to json and sent
      event_hash = {
        "timestamp" => timestamp_in_milliseconds(event.get("@timestamp")),
        "text" => (event.get("message") or ""),
      }

      # Map fields from the event to the desired form
      event_hash["fields"] = merge_hash(event.to_hash)
        .reject { |key,value| @adjusted_fields.has_key?(key) and @adjusted_fields[key] == nil }  # drop banned fields
        .map {|k,v| [ @adjusted_fields.has_key?(k) ? @adjusted_fields[k] : k,v] }  # rename fields
        .map {|k,v| { "name" => (k), "content" => v } }  # Convert a hashmap {k=>v, k2=>v2} to a list [{name=>k, content=>v}, {name=>k2, content=>v2}]

        messages.push(event_hash)
    end # events.each do

    return { "events" => messages }  # Framing required by CFAPI.
  end # def flush

  # Return a copy of the fieldname with non-alphanumeric characters removed.
  def safefield(fieldname)
    fieldname.gsub(/[^a-zA-Z0-9\_]/, '')  # TODO: Correct pattern for a valid fieldname. Must deny leading numbers.
  end

  def post(messages)
    @logger.debug("post(body)", :messages => messages)
    
    body = LogStash::Json.dump(messages)
    @logger.debug("json-dump", :body => body)
    
    @logger.debug("attempting connection", :url => @url)
    response = @client.post!(@url, :body => body)
    @logger.debug("result", :response => response)

  end # def post

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
