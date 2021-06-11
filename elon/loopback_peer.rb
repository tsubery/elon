class Elon
  class LoopbackPeer < Peer
    LISTEN_PORT = Target::DEFAULT_PORT
    LISTEN_ADDRESS = "::"

    def self.start(max_connections)
      return if max_connections.zero?
      Limits.init(self, max_connections)

      LOGGER.info("#{self} Listening on #{LISTEN_ADDRESS} #{LISTEN_PORT} for #{self.max_connections()} connections")
      EventMachine.start_server(LISTEN_ADDRESS, LISTEN_PORT, self, {
        peer: nil,
        host: LISTEN_ADDRESS,
        port: LISTEN_PORT,
        buffer: ""
      })
    end

    def get_socket_addr
      @port, @host = Socket.unpack_sockaddr_in(get_peername)
    rescue RuntimeError
      # must have disconnected quickly
    end

    def post_init
      get_socket_addr
      if host.nil? || port.nil? || self.class.too_many_connections?
        return close_connection
      end

      _port_local, host_local = Socket.unpack_sockaddr_in(get_sockname)
      LOGGER.info("#{self.class} Accepted connection on #{host_local} from #{host}:#{port}")
      @peer = EventMachine.bind_connect(
        host_local,
        nil,
        host,
        LISTEN_PORT,
        Peer, {
          peer: self,
          host: host,
          port: LISTEN_PORT
        })
    rescue EventMachine::ConnectionError
    end

    def receive_data(data)
      return unless buffer
      super
      try_proxy
    end

    def peer_connection_success
      super
      try_proxy
    end

    def peer_connection_failure
      if buffer
        # means we haven't proxied yet
        send_data(new_message(%w[version verack]))
      end
      @buffer = nil
    end

    def try_proxy
      return unless peer&.connected?

      @version_message_size ||= Message.peek(buffer)

      if @version_message_size && buffer.bytesize >= @version_message_size
        @buffer = Version.replace_nonce(buffer, @version_message_size)
        proxy_peer()
      end
    end
  end
end
