class Elon
  module Options
    def self.parse(defaults)
      options = defaults.dup
      OptionParser.new do |opts|
        opts.banner = "Usage: #{opts.program_name} [options]"

        opts.on("-c", "--crawl N", Integer, "Continously crawl and fetch peer addresses using N number of simultaneous connections") do |n|
          options[:crawl_connections] = n
        end

        opts.on("-C", "--crawl-pings N", Integer, "How many ping messages to send to each node after receiving addresses") do |n|
          options[:crawl_ping_count] = n
        end

        opts.on("-C", "--crawl-ping-ratio N", Float, "How many pings to send for each pong. For example, 1.5 will send one ping for each pong with 50% chance of sending another one. Only supported by ruby crawler") do |n|
          options[:crawl_ping_ratio] = n
        end

        opts.on("-C", "--crawl-timeout SECS", Integer, "Maximum time of each crawler connection. Ignored for connections under flood-threshold") do |n|
          options[:crawl_timeout] = n
        end

        opts.on("-o", "--once [FLAG]", FalseClass, "Only crawl once and exit") do |flag|
          options[:crawl_once] = flag.nil? ? true : !!flag
        end

        opts.on("-a", "--[no-]addrfetch [FLAG]", FalseClass, "Fetch addresses from crawled peers. Default: true") do |v|
          options[:addrfetch] = v.nil? ? true : v
        end

        opts.on("-f", "--flood-threshod N", Float, "Flood nodes with endless messages when connection latency is under this threshold.") do |n|
          options[:flood_threshold] = n
        end

        opts.on("-t", "--tunnel N", Integer, "Continously create tunnels between two ports of the same node using N number of simultaneous connections") do |n|
          options[:tunnel_connections] = n
        end

        opts.on("-p", "--publish-message [FLAG]", FalseClass, "Tell crawler to publish an extra message to all crawled nodes, works with --make and -i") do |flag|
          options[:publish_message] = flag.nil? ? true : !!flag
        end

        opts.on("-b", "--binary-message [FLAG]", FalseClass, "Accept message as binary instead of json") do |flag|
          options[:binary_message] = flag.nil? ? true : !!flag
        end

        opts.on("-s", "--split-message [FLAG]", FalseClass, "Split addrv2 message to batches of 10") do |flag|
          options[:split_message] = flag.nil? ? true : !!flag
        end


        opts.on("-d", "--dns_interval SECONDS", Integer, "Perform dns lookup for targets on start and thereafter every interval. Defaults to #{DNS_SEED_INTERVAL}") do |n|
          options[:dns_seed_interval] = n
        end

        opts.on("--bitnodes_interval SECONDS", Integer, "Perform bitnodes.io api lookup for targets on start and thereafter every interval") do |n|
          options[:bitnodes_seed_interval] = n
        end

        opts.on("--bitcoinstatus SECONDS", Integer, "Perform bitcoinstatus.net api lookup for targets on start and thereafter every interval") do |n|
          options[:bitcoinstatus_seed_interval] = n
        end

        opts.on("-m", "--make message_type", String, "Make a message, possibly reading attributes from stdin using -i flag. Defaults printing it to STDOUT which is incompatible with daemonized options. -p would publish that message to all nodes") do |message_type|
          options[:message_type] = message_type
        end

        opts.on("-i", "Read message attributes from stdin as json") do |flag|
          options[:message_attrs] = STDIN.read
        end

        opts.on("-l", "--loopback N", Integer, "Listen on port 8333 and create at most N loopback connections") do |n|
          options[:loopback_connections] = n
        end

        opts.on("-k", "--kali-connections N", Integer, "Scan using tcpkali & N number of simultanous connections") do |n|
          options[:kali_connections] = n
        end

        opts.on("-R", "--kali-send-rate", Float, "Set message rate for kali tcp, messages per second. Since kali is not aware of protocol handshake, we may want to have a rate that allows the handshake to be completed before sending second messages") do |n|
          options[:kali_send_rate] = n
        end

        opts.on("-r", "--read-only-db [FLAG]", FalseClass, "Listen for changes on db file and load when it changes. Used to coordinate with another process that does the scanning. defaults to false") do |flag|
          options[:read_only_db] = flag.nil? ? true : !!flag
        end

        opts.on("--console") do
          require 'pry'; binding.pry;
        end

        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end.parse!

      if options[:kali_connections].to_i > 0 && options[:flood_threshold] > 0
        p options
        puts STDERR, "Only ruby crawler measures latency for flooding"
        exit(1)
      end

      if options[:kali_connections].to_i > 0 && options[:crawl_connections].to_i > 0
        puts STDERR, "Only one crawler allowed at a time"
        exit(1)
      end
      crawl = 0 < options[:kali_connections].to_i + options[:crawl_connections].to_i

      if options[:split_message] && ! options[:publish_message]
        puts STDERR, "Must publish message in order to split it"
        exit(1)
      end

      if options[:publish_message]
        if !options[:message_type]
          puts STDERR, "Missing message type to publish"
          exit(1)
        end
        unless crawl
          puts STDERR, "Must set crawler/kali connections to publish"
          exit(1)
        end
      end

      options
    end
  end
end
