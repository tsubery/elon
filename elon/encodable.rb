module Encodable
  def decode_var_str(str)
    size, str = decode_var_size(str)
    [str.byteslice(0, size), slice(str, size)]
  end

  def decode_var_size(str)
    first_byte = str.bytes.first
    str = slice(str, 1)
    case first_byte
    when 253
      [str.unpack1('S<'), slice(str, 2)]
    when 254
      [str.unpack1('L<'), slice(str, 4)]
    when 255
      [str.unpack1('Q<'), slice(str, 8)]
    else
      [first_byte, str]
    end
  end

  def slice(str, offset)
    str.byteslice(offset, str.bytesize)
  end

  def encode_var_str(str)
    encode_var_size(str.bytesize) + str
  end

  def encode_var_size(size)
    if size < 253
      [size].pack("C")
    elsif size < 0x10000
      [253, size].pack("CS<")
    elsif size < 0x1000000
      [254, size].pack('CL<')
    elsif size < 0x100000000
      [255, size].pack('CQ<')
    end
  end
end
