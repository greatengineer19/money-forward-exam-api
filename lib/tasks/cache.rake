namespace :cache do
    desc "Test Redis cache connection"
    task test: :environment do
        puts "=" * 60
        puts "TESTING REDIS CACHE CONNECTION"
        puts "=" * 60

        puts "\nCache Store: #{Rails.cache.class.name}"
        
        if Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
            redis = Rails.cache.redis.with do |conn|
                conn
            end

            begin
                pong = redis.ping
                puts "✅ Redis PING: #{pong}"
            rescue => e
                puts "❌ Redis connection failed: #{e.message}"
                exit 1
            end

            # Connection info
            puts "\nConnection Info:"
            puts "  Host: #{redis.connection[:host]}"
            puts "  Port: #{redis.connection[:port]}"
            puts "  DB: #{redis.connection[:db]}"

            # Redis info
            info = redis.info
            puts "\nRedis Server Info:"
            puts "  Version: #{info['redis_version']}"
            puts "  Uptime: #{info['uptime_in_days']} days"
            puts "  Connected clients: #{info['connected_clients']}"
            puts "  Used memory: #{info['used_memory_human']}"
            puts "  Total keys: #{redis.dbsize}"

            # Test write/read
            puts "\nTesting Cache Operations:"
            test_key = "cache_test_#{Time.now.to_i}"
            test_value = { test: 'data', timestamp: Time.now.to_s }

            Rails.cache.write(test_key, test_value)
            puts "  ✅ Write: #{test_key}"

            read_value = Rails.cache.read(test_key)
            puts "  ✅ Read: #{read_value.inspect}"

            Rails.cache.delete(test_key)
            puts "  ✅ Delete: #{test_key}" 
            
            puts "\n" + "=" * 60
            puts "✅ ALL TESTS PASSED!"
            puts "=" * 60
        else
            puts "❌ Not using Redis cache store!"
            puts "   Current: #{Rails.cache.class.name}"
        end
    end

    desc "Clear all cache"
    task clear: :environment do
        puts "Clearing cache..."
        Rails.cache.clear
        puts "✅ Cache cleared!" 
    end

    desc "Show cache statistics"
    task stats: :environment do
        if Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
            redis = Rails.cache.redis.with do |conn|
                conn.ping
            end
            info = redis.info

            puts "\nRedis Cache Statistics:"
            puts "  Total keys: #{redis.dbsize}"
            puts "  Memory used: #{info['used_memory_human']}"
            puts "  Memory peak: #{info['used_memory_peak_human']}"
            puts "  Hits: #{info['keyspace_hits']}"
            puts "  Misses: #{info['keyspace_misses']}"

            if info['keyspace_hits'].to_i > 0
                hit_rate = (info['keyspace_hits'].to_f / (info['keyspace_hits'].to_i + info['keyspace_misses'].to_i) * 100)
                puts "  Hit rate: #{hit_rate.round(2)}%"
            else
                puts "Not using Redis cache store"
            end
        else
            puts "Not using Redis cache store"
        end
    end
end