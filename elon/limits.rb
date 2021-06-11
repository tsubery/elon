class Elon
  class Limits
    module Limitable
      def init(max_connections)
        Limits.init(self, max_connections)
      end

      def connected_count()
        Limits.connected_count(self)
      end

      def initiated()
        Limits.initiated(self)
      end

      def too_many_connections?()
        Limits.too_many_connections?(self)
      end

      def disconnected()
        Limits.disconnected(self)
      end

      def max_connections()
        Limits.max_connections(self)
      end
    end

    class << self
      def init(klass, max_connections)
        @max_connections ||= Hash.new {|h, k| h[k] = Float::INFINITY}
        @connected_count ||= Hash.new {|h, k| h[k] = 0}
        @max_connections[klass.name] = max_connections
      end

      def connected_count(klass)
        @connected_count[klass.name]
      end

      def initiated(klass)
        @connected_count[klass.name] += 1
      end

      def too_many_connections?(klass)
        max_connections(klass) < connected_count(klass)
      end

      def disconnected(klass)
        @connected_count[klass.name] -= 1
      end

      def max_connections(klass)
        @max_connections[klass.name]
      end

      def status
        @connected_count.reduce({}) do |key, acc|
          acc.merge(key, "#{@connected_count[key]}/#{@max_connections[key]}")
        end
      end
    end
  end
end
