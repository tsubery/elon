# frozen_string_literal: true

class Elon
  class Version
    attr_accessor :nonce, :relay, :services, :starting_height, :time, :version, :version_banner

    ID = 'version'
    INIT_ADDRESS_SIZE = 26
    INIT_ADDRESS_PATTERN = "\x00" * INIT_ADDRESS_SIZE * 2
    NONCE_OFFSET = 96
    NONCE_SIZE = 8

    include Encodable
    extend Encodable

    def defaults
      {
        nonce: rand(1..2**64),
        relay: 0,
        services: 1037,
        starting_height: 686_430 + rand(1..10_000),
        time: Time.now.to_i,
        version: 70_016 - rand(0..1),
        version_banner: '/Satoshi:0.21.0/'
      }
    end

    def initialize(attrs = {})
      defaults.merge(attrs).each do |attr, value|
        send("#{attr}=", value)
      end
    end

    def serialize
      [
        [version, services, time].pack("i<Q<q<"),
        INIT_ADDRESS_PATTERN,
        [nonce].pack("Q<"),
        encode_var_str(version_banner),
        [starting_height, relay].pack("i<C")
      ].join('')
    end

    def deserialize(str)
      @version, @services, @time,
        _addr_to, _addr_from,
        @nonce = str.unpack("i<Q<q<A#{INIT_ADDRESS_SIZE}A#{INIT_ADDRESS_SIZE}Q<C")

      @version_banner, str = decode_var_str(slice(str,4 + 8 + 8 + INIT_ADDRESS_SIZE * 2))
      @starting_height = str.unpack("C")
      @relay = str.bytes[1]
    end

    def self.replace_nonce(buffer, version_message_size)
      version_message = buffer.byteslice(0, version_message_size)
      rest = buffer.byteslice(version_message_size, buffer.bytesize)

      new_version_message = [
        version_message.byteslice(0, NONCE_OFFSET),
        [rand(1..2**64)].pack("Q"),
        version_message.byteslice(NONCE_OFFSET + NONCE_SIZE, version_message.bytesize)
      ].join('')

      [
        Message.recalculate_checksum(new_version_message),
        rest
      ]
    end
  end
end
