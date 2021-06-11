class Elon
  class Pong
    ID="pong"

    def initialize(attrs)
      @nonce = attrs["nonce"] || rand(1..2**64)
    end

    def serialize
      [@nonce].pack('Q')
    end
  end
end
