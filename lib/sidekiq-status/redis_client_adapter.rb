# adapter for redis-client client
class Sidekiq::Status::RedisClientAdapter
  def initialize(client)
    @client = client
  end

  def schedule_batch(key, options)
    @client.zrange(key, options[:start], options[:end], :byscore, :limit, options[:offset], options[:limit])
  end

  def method_missing(method, *args)
    @client.send(method, *args)
  end
end
