# frozen_string_literal: true

require 'open3'

class Tcpkali
  attr_accessor :targets, :duration
  attr_reader :output, :status_code, :streams, :first_messages, :messages, :rate, :message_files

  def initialize(duration, rate, targets)
    @duration = duration
    @rate = rate
    @targets = targets
    @streams = {}
    @output = ''
    @first_messages = []
    @messages = []
    @message_files = []
  end

  def add_first_message(message)
    @first_messages << message
  end

  def add_message(message)
    @messages << message
  end

  def add_message_file(path)
    @message_files << path
  end

  def run(logfile_path = nil)
    command = [
      'tcpkali',
      '-e',
      '--dump-all-in',
      "--duration=#{duration}",
      "--connect-rate=#{targets.count}",
      "-r#{rate}",
      messages_arg('-1', first_messages),
      messages_arg('-m', messages),
      message_files.map{|path| "-f#{path}"},
      targets.map { |t| "#{t.ip_address}:#{t.port}" },
      "--connections=#{targets.count}"
    ].flatten.join(' ')

    begin
      logfile = open_logfile(logfile_path)
      log(logfile, "Connecting to #{targets.count} peers using: #{command}\n")
      LOGGER.info("#{self.class} Connecting to #{targets.count} peers...")

      Open3.popen2e(command, rlimit_nofile: 100 + targets.count * 2) do |_stdin, io_output, wait_thr|
        @streams = self.class.parse_streams(io_output, logfile)
        yield @streams
        @status_code = wait_thr.value.exitstatus
      end

      status_code
    ensure
      logfile&.close
    end
  end

  class << self
    def parse_streams(io, logfile)
      io.each_line.lazy.map do |line|
        logfile.puts(line) if logfile
        # Sometimes thread clobber each other output
        line.gsub(/(.)(Rcv\((\d+), (\d+)\): \[)/) { |_token| "#{Regexp.last_match(1)}\n#{Regexp.last_match(2)}" }
      end.select do |line|
        line.start_with?(/Rcv\((\d+), (\d+)\): \[(.+)/) || line.start_with?("\t")
      end.chunk_while do |line|
        !line.end_with?("]\n")
      end.map do |lines|
        lines.join('')
      end.select do |message|
        message.start_with?('Rcv') && message.end_with?("]\n")
      end.map do |message|
        message =~ /^Rcv\((\d+), (\d+)\): \[(.+)/m && message.end_with?("]\n")
        content = decode_kali_output(Regexp.last_match(3).chop.chop)

        if content.bytesize == Integer(Regexp.last_match(2))
          id = Integer(Regexp.last_match(1))
          [id, content]
        else
          # Output must have been clobbered between threads
        end
      end.reject(&:nil?)
    end

    def decode_kali_output(str)
      # see src/tcpkali_data.c:77 for their escaping rules
      str.gsub(/\\(x([0-9a-f][0-9a-f])|(n\n\t|r|n|\\))/m) do |_type|
        case Regexp.last_match(1)
        when 'n'
          "\n"
        when 'r'
          "\r"
        when '\\'
          '\\'
        when "n\n\t"
          "\n"
        else
          if Regexp.last_match(1).start_with?('x')
            Regexp.last_match(2).to_i(16).chr
          else
            raise 'wtf' # seriously
          end
        end
      end
    end
  end

  private

  def encode_message(str)
    str.gsub(/./m) { |char| format('\\\\x%02x', char.ord) }
  end

  def messages_arg(name, messages, encode: true)
    (messages || []).map do |message|
      "#{name}=#{encode_message(message)}"
    end.join(' ')
  end

  def open_logfile(logfile)
    logfile && open(logfile, 'a')
  end

  def log(logfile, content)
    logfile&.print content
  end
end
