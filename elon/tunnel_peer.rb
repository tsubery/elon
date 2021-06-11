class Elon
  class TunnelPeer < Peer
    attr_reader :finish_callback, :target

    def self.connect(host,port, opts ={})
      return if too_many_connections?
      LOGGER.info("#{self} Tunneling #{host}")
      peer1=super
      super(host, port, opts.merge({peer: peer1}))
    end

    def initialize(opts)
      super
      @finish_callback = opts.fetch(:finish_callback)
      @target = opts.fetch(:target)
    end

    def receive_data(data)
      return unless buffer
      super
      try_proxy
    end

    def peer_connection_success
      try_proxy
    end

    def peer_connection_failure
      @buffer = nil
      close_connection
    end

    def try_proxy
      return unless peer&.connected?
      LOGGER.info("#{self.class} #{host} proxied successfully")
      proxy_peer()
    end

    def connection_completed
      attrs = {}
      if target.version_banner
        attrs["version_banner"] = target.version_banner
      end

      if target.services
        attrs["services"] = target.services
      end

      send_data(Message.new("version", attrs).serialize)
      super
    rescue => e
      LOGGER.error("#{host} got exception #{e.inspect} #{e.backtrace}")
    end

    def unbind
      unless connected?
        target.failed!
      end
      super
    rescue => e
      LOGGER.error("#{host} got exception #{e.inspect} #{e.backtrace}")
    end
  end
end
