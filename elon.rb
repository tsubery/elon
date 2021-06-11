#!/usr/bin/env ruby

require 'eventmachine'
require 'ipaddr'
require 'json'
require 'logger'
require 'optparse'
require 'pry'
require 'socket'

LOGGER = Logger.new(STDOUT)
DEFAULT_KALI_BATCH_TIME = 30
DEFAULT_KALI_LOGFILE = 'kali-crawler.log'
require_relative 'elon/target'
require_relative 'elon/sources'
require_relative 'elon/options'
require_relative 'elon/limits'
require_relative 'elon/addr_loop'
require_relative 'elon/peer'
require_relative 'elon/addr_fetch'
require_relative 'elon/crawler'
require_relative 'elon/tunneler'
require_relative 'elon/loopback_peer'
require_relative 'elon/encodable'
require_relative 'elon/addrman'
require_relative 'elon/message'
require_relative 'elon/tunnel_peer'
require_relative 'elon/parser'
require_relative 'elon/kali-crawler'

DEFAULTS = {
  addrfetch: true,
  crawl_connections: 0,
  crawl_timeout: 60,
  crawl_ping_count: 0,
  crawl_ping_ratio: 1.0,
  crawl_once: false,
  db_flush_interval: 60 * 10,
  db_path: Addrman::DEFAULT_DB_PATH,
  dns_seed_interval: 60*60,
  bitnodes_seed_interval: 0,
  bitcoinstatus_seed_interval: 0,
  ignored_prefixes: Addrman::DEFAULT_IGNORE_PATH,
  loopback_connections: 0,
  message_attrs: {},
  flood_threshold: -1,
  tunnel_connections: 0,
  publish_message: false,
  binary_message: false,
  split_message: false,
  message_type: nil,
  kali_connections: 0,
  kali_send_rate: 0.1,
  read_only_db: false
}

class Elon
  attr_reader :options, :publish_messages
  def initialize(options)
    @options = options
    @publish_messages = []
    make_messages
  end

  # fetch any option
  def method_missing(method_name, *args, &block)
    DEFAULTS.key?(method_name) ? options.fetch(method_name) : super
  end

  def addrman
    @addrman ||= Addrman.new(db_path, ignored_prefixes, read_only_db)
  end

  def make_messages
    return unless message_type

    unless binary_message
      message_attrs = JSON.read(message_attrs)
    end

    if split_message && message_type == Addrv2::ID
      addresses = message_attrs["addresses"] || raise("Expected addresses in message attributes for split message")
      addresses.each_cons(10).each do |batch|
        @publish_messages << Message.new(message_type, {"addresses" => batch}).serialize
      end
    else
      @publish_messages << Message.new(message_type, message_attrs).serialize
    end

    if !publish_message
      @publish_messages.each { |m| print m }
    end
  end

  def start
    if 0 == kali_connections + crawl_connections + tunnel_connections + loopback_connections
      LOGGER.info("Nothing to do here")
      exit
    end
    Signal.trap("USR1") do
      LOGGER.info("Connection status: #{Limits.status}")
    end

    sources = Sources.new(addrman, dns_seed_interval, bitnodes_seed_interval, bitcoinstatus_seed_interval)
    sources.start

    EM.run do
      sources.schedule
      if db_flush_interval.to_i > 0
        EventMachine::PeriodicTimer.new(db_flush_interval) { addrman.flush }
      end

      if kali_connections > 0
        KaliCrawler.new(
          addrman,
          addrfetch: addrfetch,
          batch_size: kali_connections.to_i,
          logfile: DEFAULT_KALI_LOGFILE,
          crawl_once: crawl_once,
          publish_messages: publish_messages,
          ping_count: crawl_ping_count,
          send_rate: kali_send_rate,
          timeout: crawl_timeout
        ).call
        exit(0)
      else
        Crawler.new(addrman, crawl_connections, {
          addrfetch: addrfetch,
          ping_count: crawl_ping_count,
          ping_ratio: crawl_ping_ratio,
          crawl_once: crawl_once,
          flood_threshold: flood_threshold,
          publish_messages: publish_messages,
          timeout: crawl_timeout
        }).start()
      end
      Tunneler.new(addrman, tunnel_connections * 2).start()
      LoopbackPeer.start(loopback_connections)
    end
  end
end

Elon.new(**Elon::Options.parse(DEFAULTS)).start


