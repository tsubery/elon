# frozen_string_literal: true

require_relative 'messages/version'
require_relative 'messages/addrv2'
require_relative 'messages/ping'
require_relative 'messages/pong'
require_relative 'messages/verack'
require_relative 'messages/getheaders'
require 'digest'

class Elon
  class Message
    MAIN_NETWORK = "\xF9\xBE\xB4\xD9"
    MAIN_NETWORK_INT = 3_652_501_241
    HEADER_SIZE = 24
    EMPTY_CHECKSUM = "]\xF6\xE0\xE2"
    attr_accessor :message_type, :stream_id, :attrs

    def initialize(message_type, attrs = {})
      @attrs = attrs
      @message_type = message_type
      raise ArgumentError, 'Must provide message type' if message_type.nil?
    end

    MESSGAE_TYPES = {
      Version::ID => Version,
      Addrv2::ID => Addrv2,
      Ping::ID => Ping,
      Getheaders::ID => Getheaders
    }.freeze

    def message_class
      MESSGAE_TYPES[message_type]
    end

    def payload=(payload)
      @payload = payload
    end

    def payload
      @payload ||= message_class&.new(attrs)&.serialize || ''
    end

    def checksum
      self.class.checksum(payload)
    end

    def self.checksum(payload)
      if payload.empty?
        EMPTY_CHECKSUM
      else
        Digest::SHA256.digest(Digest::SHA256.digest(payload))[0..3]
      end
    end

    def serialize
      @message = payload.empty? ?
        (self.class.message_cache[message_type] ||= do_serialize) :
        do_serialize
    end

    def do_serialize
      [
        MAIN_NETWORK,
        message_type,
        payload.length,
        checksum,
      ].pack("A4a12L<A4") + payload
    end

    def deserialize_payload
      message_class&.deserialize(payload) || payload
    end

    class << self
      def message_cache
        @cache ||= {}
      end

      def peek(message)
        return nil if message.bytesize < HEADER_SIZE
        _network, _message_type, payload_length = message.unpack('A4A12L<')
        payload_length + HEADER_SIZE
      end

      def serialize_no_payload(type)
        message_cache[type] ||= new(type).serialize
      end

      def deserialize(message, stream_id: nil, message_filters: [], verify_checksum: false)
        message_filters = Array(message_filters)
        network_int, message_type, payload_length, checksum = message.unpack('L<A12L<A4')
        next_message = message.byteslice(HEADER_SIZE + payload_length, message.bytesize)
        new_message = new(message_type)
        new_message.payload = message.byteslice(HEADER_SIZE, payload_length)
        new_message.stream_id = stream_id

        filtered = !message_filters.empty? && !message_filters.include?(message_type)
        if filtered
          [nil, next_message]
        elsif network_int != MAIN_NETWORK_INT ||
          (verify_checksum && new_message.checksum.bytes != checksum.bytes)
          [nil, nil]
        else
          [new_message, next_message]
        end
      end

      def recalculate_checksum(message_data)
        payload = message_data.byteslice(HEADER_SIZE, message_data.bytesize)
        [
          message_data.byteslice(0, 20), #original header without checksum
          [Message.checksum(payload)].pack("A4"),
          message_data.byteslice(24, message_data.bytesize)
        ].join('')
      end
    end
  end
end
