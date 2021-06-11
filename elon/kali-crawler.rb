# frozen_string_literal: true

require_relative 'message'
require_relative 'addrman'
require_relative 'tcpkali'
require_relative 'target'
require 'tempfile'

class Elon
  class KaliCrawler
    IPV6_SUPPORT_LINK = 'https://github.com/satori-com/tcpkali/pull/73'

    attr_reader :addrman, :logfile, :publish_message_path, :timeout, :addrfetch
    attr_accessor :network_filter, :batch_size, :publish_messages, :once, :ping_count, :send_rate

    def initialize(addrman, batch_size:, logfile:, publish_messages: , crawl_once:, send_rate:, ping_count:, timeout:, addrfetch:)
      @addrfetch = addrfetch
      @addrman = addrman
      @timeout = timeout
      @logfile = logfile
      @batch_size = batch_size
      @reachable_count = 0
      @publish_messages = publish_messages
      @ping_count = ping_count
      @send_rate = send_rate

      # Assume tcpkali supports both 1:ipv4 & 2:ipv6 address
      # Latest version has a bug parsing ipv6 ip addresses, see link above
      # So we might change the filter when we encounter an error
      @network_filter = Target::IPv6
    end

    def addresses
      addrman.pending.values + addrman.completed.values
    end

    def create_message(message_types)
      Array(message_types).map  do |type|
        Message.new(type).serialize
      end.join('')
    end

    def call
      Tempfile.create('published_message') do |f|
        if publish_messages.size > 0
          publish_messages.each{ |m| f.write(m) }
          f.flush
          @publish_message_path = f.path
        end

        begin
          crawl
        end while !once
      end
    end

    def crawl
      addrman.all_pending!
      @reachable_count = 0
      while (targets = addrman.get_batch(batch_size, network_filter)).size.positive?
        tcpkali = Tcpkali.new(timeout, send_rate, targets)
        # Send version immediately
        tcpkali.add_first_message(create_message('version'))
        # After few seconds, send the rest of the handshake and optionally getaddr
        getaddr = addrfetch ? ' getaddr' : ''
        tcpkali.add_message(create_message(%w[wtxidrelay sendaddrv2 verack] + getaddr))
        unless publish_messages.empty?
          tcpkali.add_message_file(publish_message_path)
        end
        if ping_count.to_i > 0
          tcpkali.add_message((["ping"]* ping_count).join(" "))
        end

        File.delete(logfile) if File.exist?(logfile)

        begin
          addresses = nil
          reachable = {}
          exit_status = tcpkali.run(logfile) do |streams|
            counted_streams =
              Enumerator::Lazy.new(streams) do |yielder, *args|
                reachable[args.first.first] = true
                yielder.yield(*args)
              end
            addresses = Parser.parse_multiple(counted_streams, Addrv2::ID).flat_map do |messages|
              Parser.parse_addresses(messages).select do |addr|
                addr.network <= network_filter
              end
            end.to_a
          end

          case exit_status
          when 68
            puts "tcpkali version does not seem to support ipv6 addresses\n See #{IPV6_SUPPORT_LINK}"
            self.network_filter = Target::IPv4
          when 0..1
            puts 'Parsing bitcoin messages'

            @reachable_count += reachable.count # peers who have responded
            addrman.completed!(targets)
            new_count = addrman.add_pending(addresses)

            puts "Parsed #{addresses.count} addresses from #{reachable.count} peers. #{new_count} new targets found. Scanned #{addrman.completed.count}/#{addrman.total_count.inspect}. #{@reachable_count} reachable peers"
          else
            raise "Unknown exit code #{tcpkali.status_code} running command, you may want to run it manually. See #{logfile} for more details"
          end
        rescue Errno::E2BIG
          new_batch_size = (batch_size * 0.9).to_i
          puts "batch_size of #{batch_size} is causing argument list to be to long. Reducing to #{new_batch_size}"
          self.batch_size = (new_batch_size)
        end
      end
      LOGGER.info("Kali crawler finished")
      addrman.flush
    end
  end
end
