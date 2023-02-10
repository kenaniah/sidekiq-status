# adapter for redis-rb client
class Sidekiq::Status::RedisAdapter
  def initialize(client)
    @client = client
  end

  def scan(**options, &block)
    @client.scan_each(**options, &block)
  end

  def schedule_batch(key, options)
    @client.zrangebyscore key, options[:start], options[:end], limit: [options[:offset], options[:limit]]
  end

  def method_missing(method, *args)
    @client.send(method, *args)
  end
end
