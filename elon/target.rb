require 'time'
class Target
  attr_accessor :ip_address, :port, :network, :services, :last_seen, :status, :failures, :reachable, :latency, :version_banner

  IPv4 = 1
  IPv6 = 2
  DEFAULT_PORT = 8333

  def initialize(ip_address, port, services, last_seen, status = Addrman::PENDING, failures = [], reachable = nil, latency = nil, version_banner = nil)
    @ip_address = ip_address
    @port = port
    @network = ip_address =~ /^\d+\.\d+\.\d+\.\d+$/ ? IPv4 : IPv6
    @services = services
    @last_seen =
      case
        last_seen
      when Time
        last_seen
      when Integer
        Time.at(last_seen)
      when String
        Time.parse(last_seen)
      else
        raise "Unsupported time #{last_seen.inspect}"
      end
    @status = status
    @reachable = reachable
    @failures = failures.respond_to?(:to_a) && failures || []
    @version_banner = version_banner
  end

  def full_node?
    services != 0 ? (services % 2) == 1 : false
  end

  def wallet?
    services != 0 ? (services % 2) == 0 : false
  end

  def self.new_ntoh(*args)
    ip = IPAddr.new_ntoh(args.shift).to_s
    new(ip, *args)
  end

  def self.default_attrs
    {
      "last_seen" => Time.now.to_i + 9*60,
      "services" => 1037,
      "port" => DEFAULT_PORT,
      "status" => Addrman::PENDING
    }
  end

  def self.from_hash(attrs)
    attrs = default_attrs.merge(attrs)
    Target.new(
      attrs["ip_address"],
      attrs["port"],
      attrs["services"],
      attrs["last_seen"],
      attrs["status"],
      attrs["failures"],
      attrs["reachable"],
      attrs["latency"],
      attrs["version_banner"],
    )
  end

  def to_h
    {
      "ip_address" => ip_address,
      "port" => port,
      "network" => network,
      "services" => services,
      "last_seen" => last_seen,
      "status" => status,
      "reachable" => reachable,
      "latency" => latency,
      "failures" => failures,
      "version_banner" => version_banner
    }
  end

  def full_address
    # full form of ipv6 for event machine
    @full_address ||= IPAddr.new(ip_address).to_string
  end

  def reached!(latency)
    @failures.clear
    @last_seen = Time.now
    @latency = latency
    @reachable = true
  end

  def failed!
    @failures << Time.now
    @failures = @failures.last(15)
  end
end
