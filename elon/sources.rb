require 'net/http'
class Elon
  class Sources
    DNS_SEEDS = %w[
      seed.bitcoin.sipa.be dnsseed.bluematt.me dnsseed.bitcoin.dashjr.org seed.bitcoinstats.com
      seed.bitcoin.jonasschnelli.ch seed.btc.petertodd.org seed.bitcoin.sprovoost.nl
      dnsseed.emzy.de seed.bitcoin.wiz.biz seed.bitnodes.io
    ].freeze

    attr_reader :addrman, :dns_seed_interval, :bitnodes_seed_interval, :bitcoinstatus_seed_interval, :db_path, :db_read_only
    def initialize(addrman, dns_seed_interval, bitnodes_seed_interval, bitcoinstatus_seed_interval)
      @addrman = addrman
      @dns_seed_interval = dns_seed_interval
      @bitnodes_seed_interval = bitnodes_seed_interval
      @bitcoinstatus_seed_interval = bitcoinstatus_seed_interval
    end

    class DbWatcher < EventMachine::FileWatch
      def initialize(reload)
        @reload = reload
      end
      def file_modified()
        LOGGER.info("Database modified, loading new targets")
        @reload.call()
      end
    end

    def db_path
      addrman.db_path
    end

    def start()
      add_seeds_now(bitcoinstatus_seed_interval) { self.class.bitcoinstatus }
      add_seeds_now(bitnodes_seed_interval) { self.class.bitnodes }
      add_seeds_now(dns_seed_interval) { self.class.dns }
    end


    def schedule
      reload = Proc.new do
        addrman.add_pending(self.class.from_json_file(db_path))
      end

      if addrman.read_only && File.exists?(db_path)
        LOGGER.info("#{self.class} Monitoring file #{db_path} for changes")
        EM.watch_file(db_path, DbWatcher, reload)
      end

      add_seeds_periodically(bitcoinstatus_seed_interval) { self.class.bitcoinstatus }
      add_seeds_periodically(bitnodes_seed_interval) { self.class.bitnodes }
      add_seeds_periodically(dns_seed_interval) { self.class.dns }
    end

    def add_seeds_now(interval, &block)
      return unless interval > 0
      addrman.add_pending(yield)
    end

    def add_seeds_periodically(interval, &block)
      return unless interval > 0

      EventMachine::PeriodicTimer.new(interval) do
        begin
          targets = []
          begin
            targets = yield
            LOGGER.info("Loaded #{targets.count} targets")
          rescue => e
            LOGGER.error("Error fetching new targets #{e.inspect}")
          end
          addrman.add_pending(targets)
        rescue => e
          LOGGER.error("Failed to seed #{e.inspect} #{e.backtrace}")
        end
      end
    end

    class << self
      def dns
        DNS_SEEDS.flat_map do |dns_seed|
          Resolv::DNS.open do |dns|
            dns.getresources(dns_seed, Resolv::DNS::Resource::IN::A).map do |result|
              Target.new(result.address.to_s, Target::DEFAULT_PORT, 0, Time.now - 1 * 60 * 60)
            end
          end
        end
      rescue => e
        LOGGER.error(e.inspect)
        LOGGER.error(e.backtrace)
      end

      def bitnodes
        http = Net::HTTP.new('bitnodes.io', 443);
        http.use_ssl = true;
        request = http.request_get('/api/v1/snapshots/latest/', { 'Accept' => 'application/json;' })
        return [] unless request&.code&.start_with?("2")

        JSON.parse(request.body).fetch("nodes").map do |pair|
          pair.flatten
        end.reject do |array|
          array.first =~ /onion/
        end.map do |address, _version, version_banner, last_seen, services|
          segments = address.split(":")
          port = segments.pop
          ip_address = IPAddr.new(segments.join(':').tr('[]',''))
          t = Target.new(
            ip_address.to_s, #normalized
            port,
            services,
            Time.at(last_seen)
          )
          t.version_banner = version_banner
          t
        end
      end

      def bitcoinstatus
        http = Net::HTTP.new('bitcoinstatus.net')
        request = http.request_get('/active_nodes.json')
        return [] unless request&.code&.start_with?("2")
        JSON.parse(request.body).map{|hash| Target.from_hash(hash)}
      end

      def from_json_file(db_path)
       return [] unless db_path && File.exist?(db_path)

       JSON.parse(File.read(db_path)).map { |h| Target.from_hash(h) }
      end
    end
  end
end
