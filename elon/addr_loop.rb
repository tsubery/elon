class Elon
  class AddrLoop
    RETRY_AFTER = 30

    attr_accessor :addrman, :max_connections, :peer_klass, :opts

    def initialize(addrman, max_connections, opts = {})
      @addrman = addrman
      @opts = opts
      @open = 0
      @max_connections = max_connections
      peer_klass.init(max_connections)
    end

    def on_finish
      @open -= 1
      self.loop()
    end

    def start()
      return if peer_klass.max_connections.zero?
      LOGGER.info("#{self} Starting with #{peer_klass.max_connections} connections limit")
      self.loop()
    end

    def next
      raise NotImplementedError
    end

    def on_connect_fail(target)
      @open -= 1
      target.failed!
      self.loop()
    rescue => e
      LOGGER.error("Error marking target as failed #{target.ip_address} #{e.inspect}")
    end

    def after
      LOGGER.info("#{self.class.name} Finished. Sleeping for #{RETRY_AFTER} seconds")
      EM.add_timer(RETRY_AFTER) { self.loop() }
    end

    def loop
      while (@open < max_connections && (target = self.next()))
        @open += 1
        begin
          peer_klass.connect(
            target.full_address,
            target.port, opts.merge({
              finish_callback: method(:on_finish),
              target: target
            }))
        rescue => e
          LOGGER.error("Error connecting to #{target.ip_address} #{e.inspect}")
          on_connect_fail(target)
        end
      end
      if @open != max_connections
        self.after()
      else
        # wait for connection on_finish event to loop again
      end
    end
  end
end
