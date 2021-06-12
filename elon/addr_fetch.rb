class Elon
  class AddrFetch < Peer
    attr_reader :parser, :addresses, :finish_callback, :target, :timeout, :ping_ratio, :pings_left, :flood_threshold, :latency, :flooding, :publish_messages, :addrfetch
    RELAY_ADDRESSES = 10
    FLOOD_PING_RATIO = 2

    def self.get_addr_sequence
      @get_addr_sequence ||= new_message(%w[wtxidrelay sendaddrv2 verack getaddr])
    end

    def self.getheaders
      @getheaders= Message.new("getheaders")
      @getheaders.payload = Getheaders.example
      @getheaders = @getheaders.serialize
    end

    def connection_completed
      @latency = Time.now - @init_time
      if latency < flood_threshold
        @flooding = true
        @ping << self.class.getheaders
        @ping_ratio = FLOOD_PING_RATIO
        EM.cancel_timer(@timer)
      end
      target.reached!(latency)
      send_data(new_message("version"))
      super
    end

    def initialize(opts)
      super
      @addrfetch = opts.fetch(:addrfetch)
      @timeout = opts.fetch(:timeout)
      @publish_messages = opts.fetch(:publish_messages)
      @flood_threshold = opts.fetch(:flood_threshold)
      @pings_left = opts.fetch(:ping_count)
      @ping_ratio = opts.fetch(:ping_ratio)
      @finish_callback = opts.fetch(:finish_callback)
      @target = opts.fetch(:target)

      message_filter = [Verack::ID, Version::ID, Ping::ID]

      if pings_left > 0
        message_filter << Pong::ID
      end
      if addrfetch
        message_filter << Addrv2::ID
      end

      @parser = Parser.new(message_filter)
      @addresses = []
      @timer = EM.add_timer(timeout) { close_connection }
      @init_time = Time.now
      @ping = new_message(Ping::ID)
      @count = 0
    end

    def send_ping()
      return unless flooding || pings_left > 0
      ping_multiplier = ping_ratio.floor
      maybe = (ping_ratio - ping_ratio.floor) < rand(0.0..1.0) ? 1 : 0
      @count += ping_multiplier + maybe
      send_data(@ping * (ping_multiplier + maybe))
    end

    def receive_data(data)
      parser.new_data(data).each do |message|
        case message.message_type
        when Version::ID
          if message.payload.bytesize > 80
            size = message.payload.bytes[80]
            banner = message.payload.byteslice(81, size)
            target.version_banner=(banner)
          end
        when Verack::ID
          send_data(self.class.get_addr_sequence)
          publish_messages.each{ |m| send_data(m)}
          send_ping
        when Addrv2::ID
          @addresses += Parser.parse_addresses(message)
          send_ping
        when Pong::ID
          @pings_left -= 1
          send_ping
        when Ping::ID
          message.message_type = "pong"
          send_data(message.serialize)
        end
      end
      if !@flooding &&
          pings_left <= 0 &&
          publish_messages.empty? &&
          (addresses.count > RELAY_ADDRESSES || !addrfetch)
        # Our work is done
        close_connection
      end
    rescue => e
      LOGGER.error("#{host} got exception #{e.inspect} #{e.backtrace}")
    end

    def unbind
      unless connected?
        target.failed!
      end
      super
      finish_callback.call(target, addresses)
    rescue => e
      LOGGER.error("#{host} got exception #{e.inspect} #{e.backtrace}")
    end
  end
end
