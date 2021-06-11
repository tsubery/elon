class Elon
  class Parser
    attr_reader :buffer, :expected_bytes, :parsed_header, :verify_checksum, :stream_id
    attr_accessor :message_filters

    def initialize(message_filters = [], verify_checksum: false)
      @verify_checksum = verify_checksum
      @message_filters = message_filters
      @buffer = ""
      @expected_bytes = Message::HEADER_SIZE
      @parsed_header = false
      @@stream_id ||= 0
      @stream_id = (@@stream_id+=1)
    end

    def enough_buffer
      buffer.bytesize >= expected_bytes
    end

    def new_data(new_data)
      return [] unless @buffer
      buffer << new_data
      messages = []
      while buffer && enough_buffer
        if !parsed_header && enough_buffer
          @expected_bytes = Message.peek(buffer)
          @parsed_header = true
        end

        if parsed_header && enough_buffer
          @parsed_header = false
          @expected_bytes = Message::HEADER_SIZE
          begin
            new_message, rest = Message.deserialize(buffer, stream_id: stream_id, message_filters: message_filters, verify_checksum: verify_checksum)
            @buffer = rest
            messages << new_message if new_message
          rescue StandardError => e
            LOGGER.error("Failured parsing bitcoin message #{e.inspect} #{e.backtrace}")
            @buffer = nil
          end
        end
      end
      messages
    end

    def self.parse_addresses(message)
      if message.message_type == Addrv2::ID
        Addrv2.deserialize(message.payload).addresses
      else
        []
      end
    rescue StandardError => e
      LOGGER.error("Failured parsing bitcoin addresses #{e.inspect} #{e.backtrace}")
      []
    end

    def self.parse_multiple(streams, message_filters)
      parsers = Hash.new {|h, k| h[k] = Parser.new(message_filters, verify_checksum: true) }
      streams.flat_map do |id, new_data|
        parsers[id].new_data(new_data)
      end
    end
  end
end
