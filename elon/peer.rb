class Elon
  class Peer < EventMachine::Connection
    attr_reader :peer, :host, :port, :buffer, :max_connections
    attr_accessor :buffer

    extend Limits::Limitable

    def self.connect(host, port, opts = {})
      EventMachine.connect(
        host,
        port,
        self,
        opts.merge({
          host: host,
          port: port
        })
      )
    end

    def initialize(opts)
      self.class.initiated
      @peer = opts[:peer]
      @host = opts.fetch(:host)
      @port = opts.fetch(:port)
      @buffer = opts.fetch(:buffer, []).dup # We don't want shared buffered
      @connected = false
    end

    def receive_data(data)
      buffer << data
    rescue => e
      LOGGER.error("#{host} got exception #{e.inspect} #{e.backtrace}")
    end

    def send_buffer(dst)
      return if buffer.empty?
      buffer.each{|d| dst.send_data(d)}
      self.buffer = []
    end

    def proxy_peer()
      LOGGER.info("#{host} Setting proxy to peer #{peer.signature}")
      [
        [peer, self],
        [self, peer]
      ].each do |src, dst|
         src.send_buffer(dst)
         src.proxy_incoming_to(dst)
      end
    rescue => e
      LOGGER.error("#{host} got exception #{e.inspect} #{e.backtrace}")
    end

    def peer_connection_success
      #noop
    end

    def connection_completed
      @connected = true
      send_buffer(self)
      peer&.peer_connection_success
    end

    def peer_connection_failure
      close_connection
    end

    def unbind
      @connected = false
      self.class.disconnected
      if peer && !peer.error?
        peer.peer_connection_failure
      end
    rescue => e
      LOGGER.error("#{host} got exception #{e.inspect} #{e.backtrace}")
    end

    def connected?
      !!@connected
    end

    def new_message(*args)
      self.class.new_message(*args)
    end

    def self.new_message(message_types)
      Array(message_types).map{ |type|
        Message.serialize_no_payload(type)
      }.join("")
    end
  end
end
