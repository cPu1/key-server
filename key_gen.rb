require 'securerandom'
require 'timers'
require 'monitor'

class KeyGen
  include MonitorMixin

  def initialize(options = {})
    @keys = {}
    @blocked_keys = {}
    @keepalive = options.fetch(:keepalive, 60 * 5)
    @release_after = options.fetch(:release_after, 60)
    # @options = {keepalive: 60 * 5, release_after: 60}.merge(options)
    start_timer
    super()
  end

  def start_timer()
    @timers = Timers::Group.new
    Thread.new {
      loop do
        @timers.after(5) {} #
        @timers.wait
      end
    }
  end

  def generate()
    synchronize do
      key = SecureRandom.hex(20)
      @keys[key] = make_timer(key)
    end
  end

  def block()
    synchronize do
      key = nil
      timer = nil
      @keys.each do |k, v|
        key = k
        timer = v
        break
      end

      return nil if !key

      timer.cancel
      @keys.delete(key)

      #release
      @blocked_keys[key] = make_blocked_timer(key)
      key
    end
  end

  def make_timer(key)
    @timers.after(@keepalive) do
      synchronize do
        @keys.delete(key)
      end
    end
  end

  def make_blocked_timer(key)
    @timers.after(@release_after) do
      synchronize do
        @blocked_keys.delete(key)
        @keys[key] = make_timer(key)
      end
    end
  end

  def unblock(key)
    synchronize do
      timer = @blocked_keys.delete(key)
      raise KeyGenError, key if !timer
      timer.cancel
      @keys[key] = make_timer(key)
    end
  end

  def delete(key)
    synchronize do
      timer = @keys.delete(key) || @blocked_keys.delete(key)
      raise KeyGenError, key if !timer
      timer.cancel
    end
  end

  def refresh_key(key)
    synchronize do
      timer = @keys[key]
      raise KeyGenError, key if !timer
      timer.cancel
      @keys[key] = make_timer(key)
    end
  end

  def inspect()
    return "keys: #{@keys.keys}, blocked_keys: #{@blocked_keys.keys}"
  end

  private :make_timer, :make_blocked_timer, :start_timer
end

class KeyGenError < StandardError
  def initialize(key)
    super("Failed to find key \"#{key}\"")
  end
end

#TODO intercept
