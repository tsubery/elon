class Elon
  class Crawler < AddrLoop
    attr_accessor :addrman, :only_once

    def initialize(*args)
      @peer_klass = AddrFetch
      @only_once = args.last.fetch(:crawl_once)
      super(*args)
      addrman.all_pending!
    end

    def on_finish(target, addresses)
      addrman.completed!(target)
      new_count = addrman.add_pending(addresses)
      LOGGER.info("#{self.class.name} Found #{new_count} new addresses. Finished #{addrman.completed.count}/#{addrman.total_count}")
      super()
    end

    def next()
      addrman.pop
    end

    def on_connect_fail(target)
      super
      addrman.completed!(target)
    end

    def after()
      addrman.flush
      if only_once
        LOGGER.info("#{self.class} Finished. Quitting")
        EM.stop
      end
      addrman.all_pending!
      super
    end
  end
end
