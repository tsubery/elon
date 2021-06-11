class Elon
  class Tunneler < AddrLoop

    def initialize(*args)
      @peer_klass = TunnelPeer
      super(*args)
    end

    def next
      addrman.get_random_reachable
    end
  end
end
