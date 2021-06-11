# frozen_string_literal: true
require 'ipaddr'
class Elon
  class Addrv2
    attr_accessor :addresses
    include Encodable
    extend Encodable

    ID = 'addrv2'

    def initialize(attrs = {})
      @addresses = (attrs["addresses"] || []).map do |attrs|
        Target.from_hash(attrs)
      end
    end

    def add_address(address)
      @addresses << address
    end

    def serialize
      [
        encode_var_size(addresses.length),
        addresses.map{|a| serialize_address(a)}
      ].flatten.join('')
    end

    def serialize_address(addr)
      [addr.last_seen&.to_i].pack('L<') +
        encode_var_size(addr.services) +
        [addr.network].pack("C") +
        encode_var_str(IPAddr.new(addr.ip_address).hton()) +
        [addr.port].pack("S>")
    end

    class << self
      def deserialize(str)
        count, str = decode_var_size(str)
        new.tap do |instance|
          while count.positive? && str.bytesize > 12
            addr, str = deserialize_addr(str)
            addr && instance.add_address(addr)
            count -= 1
          end
        end
      end

      def deserialize_addr(str)
        last_seen = str.unpack1('L<')
        if last_seen > 1_720_739_904 || last_seen < 1_520_739_904
          raise "invalid last_seen #{last_seen}" # Sanity check for deserialization
        end

        str = slice(str, 4)
        services, str = decode_var_size(str)
        _network = str.bytes.first # we use regex to populate it
        str = slice(str, 1)
        address, str = decode_var_str(str)
        port = str.unpack1('S>')
        str = slice(str, 2)
        addy = Target.new_ntoh(
          address,
          port,
          services,
          last_seen
        )
        [addy, str]
      rescue IPAddr::AddressFamilyError
        # skip wierd addresses
        [nil, str]
      rescue StandardError => e
        p e
        [nil, '']
      end
    end
  end
end
