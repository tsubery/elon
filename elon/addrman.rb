# frozen_string_literal: true

require 'resolv'
require 'set'
require_relative 'target'
require 'json'

class Addrman
  attr_reader :by_address, :by_status, :pending, :in_progress, :completed, :db_path, :reachable, :read_only
  PENDING=:pending
  COMPLETED=:completed
  IN_PROGRESS=:in_progress
  MAX_CONNECT_FAILURES = 10
  DEFAULT_DB_PATH="targets.json"
  DEFAULT_IGNORE_PATH="ignored_prefixes.txt"
  DEFAULT_FLUSH_INTERVAL=10 * 60
  CUTOFF_HOURS = 12

  def initialize(db_path = DEFAULT_DB_PATH, ignored_path = DEFAULT_IGNORE_PATH, read_only = false)
    @db_path = db_path
    @read_only = read_only
    @access = Mutex.new

    @by_address = {}
    @by_status = {
      PENDING => (@pending = {}),
      IN_PROGRESS => (@in_progress = {}),
      COMPLETED => (@completed = {})
    }
    @reachable = {}

    if ignored_path && File.exists?(ignored_path)
      @ignored_prefixes = File.read(ignored_path).lines.map(&:chomp)
    else
      @ignored_prefixes = []
    end

    unless read_only
      Signal.trap("INT") { flush(true) }
      Signal.trap("TERM") { flush(true) }
    end
  end

  def flush(terminate = false)
    return if read_only
    File.write(db_path, by_address.values.map(&:to_h).to_json)
    terminate && exit
  end

  def all_pending!
    @access.synchronize {
      change_status(completed.values, COMPLETED, PENDING)
      change_status(in_progress.values, IN_PROGRESS, PENDING)
    }
  end

  def add_pending(addresses)
    @access.synchronize {
      new = addresses.map do |a|
        a.status = PENDING
        a.ip_address = a.ip_address.to_s
        [a.ip_address, a]
      end.select do |k,v|
        # We already have it
        if by_address[k]
          by_address[k].last_seen = [v.last_seen, by_address[k].last_seen].sort[1]
          false
        else
          acceptable_target?(v)
        end
      end.to_h

      reachable.merge!(new.select{|_k,v| v.reachable}.to_h)
      by_address.merge!(new)
      pending.merge!(new)
      new.count
    }
  end

  def acceptable_target?(target)
    @ignored_prefixes.none?{|prefix| target.ip_address.start_with?(prefix)} &&
       target.last_seen >= Time.now - (CUTOFF_HOURS * 60 * 60) &&
       target.failures.count <= MAX_CONNECT_FAILURES &&
       !target.wallet?
  end

  def change_status(addresses, from, to)
    Array(addresses).each do |a|
      key = a.ip_address
      by_address[key].status = to
      by_status[from].delete(key)
      by_status[to][key] = a
    end
  end

  def pop()
    @access.synchronize {
      return unless (key = pending.keys.sample)
      pending[key].tap do |a|
        change_status(a, PENDING, IN_PROGRESS)
      end
    }
  end

  def completed!(addresses)
    @access.synchronize {
      Array(addresses).each do |a|
        key = a.ip_address
        change_status(a, IN_PROGRESS, COMPLETED)
        change_status(a, PENDING, COMPLETED)
        if a.reachable
          reachable[key] = a
        elsif a.failures.count > MAX_CONNECT_FAILURES
          pending.delete(key)
          in_progress.delete(key)
          completed.delete(key)
          by_address.delete(key)
          reachable.delete(key)
        end
      end
    }
  end

  def remove(key)
    pending.delete(key)
    in_progress.delete(key)
    completed.delete(key)
    reachable.delete(key)
    by_address.delete(key)
  end

  def get_random_reachable
    while (t = reachable[reachable.keys.sample])
      if t.reachable
        return t
      else
        reachable.delete(t.ip_address)
      end
    end
  end

  def get_batch(count, network_filter = nil)
    pending.lazy.reject do |_k,v|
      network_filter && v.network > network_filter
    end.first(count).map{|k,v| v}
  end

  def total_count
    completed.count + pending.count + in_progress.count
  end

  def add_dns_seeds
    addresses = DNS_SEEDS.flat_map do |dns_seed|
      Resolv::DNS.open do |dns|
        dns.getresources(dns_seed, Resolv::DNS::Resource::IN::A).map do |result|
          Target.new(result.address.to_s, 8333, 0, Time.now - 1 * 60 * 60)
        end
      end
    end
    add_pending(addresses)
  end
end
