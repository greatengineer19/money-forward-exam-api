class ApiClient
    include HTTParty
    base_uri 'https://api.example.com'

    def initialize
        @cache = Rails.cache
        @timeout = 30
    end
    
    # Basic cache with TTL
    def fetch_with_cache(endpoint, cache_key, ttl: 1.hour)
        @cache.fetch(cache_key, expires_in: ttl) do
            get_request(endpoint)
        end 
    end

    # Cache with race condition protection
    def fetch_with_race_protection(endpoint, cache_key, ttl: 1.hour)
        @cache.fetch(cache_key, expires_in: ttl, race_condition_ttl: 10.seconds) do
            get_request(endpoint)
        end
    end

    # Multi-level caching (memory + Redis)
    def fetch_with_multilevel(endpoint, cache_key, ttl: 1.hour)
        memory_key = "memory:#{cache_key}"

        # Check memory cache first
        result = RequestStore.store[memory_key]
        return result if result

        # Check Redis cache
        result = @cache.fetch(cache_key, expires_in: ttl) do
            get_request(endpoint)
        end

        # Store in memory cache
        RequestStore.store[memory_key] = result
        result
    end

    # Conditional caching based on response
    def fetch_with_conditional_cache(endpoint, cache_key, ttl: 1.hour)
        @cache.fetch(cache_key, expires_in: ttl) do
            response = get_request(endpoint)
            response if cacheable?(response)
        end
    end

    # Cache with ETag support
    def fetch_with_etag(endpoint, cache_key)
        cached_data = @cache.read(cache_key)
        etag = @cache.read("#{cache_key}:etag")

        headers = {}
        headers['If-None-Match'] = etag if etag

        response = self.class.get(endpoint, headers: headers, timeout: @timeout)

        if response.code == 304
            cached_data
        else
            @cache.write(cache_key, response.parsed_response, expires_in: 1.hour)
            @cache.write("#{cache_key}:etag", response.headers['etag'])
            response.parsed_response
        end
    rescue => e
        Rails.logger.error("API Error: #{e.message}")
        cached_data || raise
    end

    # Cache with Last-Modified support
    def fetch_with_last_modified(endpoint, cache_key)
        cached_data = @cache.read(cache_key)
        last_modified = @cache.read("#{cache_key}:last_modified")

        headers = {}
        headers['If-Modified-Since'] = last_modified if last_modified

        response = self.class.get(endpoint, headers: headers, timeout: @timeout)

        if response.code == 304
            cached_data
        else
            @cache.write(cache_key, response.parsed_response, expires_in: 1.hour)
            @cache.write("#{cache_key}:last_modified", response.headers['last-modified'])
            response.parsed_response
        end
    rescue => e
        Rails.logger.error("API Error: #{e.message}")
        cached_data || raise
    end

    # Stale-while-revalidate pattern
    def fetch_with_swr(endpoint, cache_key, fresh_ttl: 5.minutes, stale_ttl: 1.hour)
        fresh_key = "#{cache_key}:fresh"
        stale_key = "#{cache_key}:stale"

        # Return fresh cache if available
        fresh_data = @cache.read(fresh_key)
        return fresh_data if fresh_data

        # Return stale cache and refresh in background
        stale_data = @cache.read(stale_key)
        if stale_data
            refresh_in_background(endpoint, cache_key, fresh_ttl, stale_ttl)
            return stale_data
        end

        # No cache, fetch synchronously
        refresh_cache(endpoint, cache_key, fresh_ttl, stale_ttl)
    end

    # Cache with fallback chain
    def fetch_with_fallback_chain(endpoints, cache_key, ttl: 1.hour)
        @cache.fetch(cache_key, expires_in: ttl) do
            endpoints.each do |endpoint|
                begin
                    return get_request(endpoint)
                rescue => e
                    Rails.logger.warn("Failed endpoint #{endpoint}: #{e.message}")
                    next
                end
            end
        end

        raise "All endpoints failed"
    end

    # Batch caching
    def fetch_batch(endpoint_map, base_cache_key, ttl: 1.hour)
        results = {}
        uncached_keys = []

        # Check cache for all keys
        endpoint_map.each do |key, endpoint|
            cache_key = "#{base_cache_key}:#{key}"
            cached = @cache.read(cache_key)

            if cached
                results[key] = cached
            else
                uncached_keys << key
            end
        end

        # Fetch uncached items
        uncached_keys.each do |key|
            endpoint = endpoint_map[key]
            cache_key = "#{base_cache_key}:#{key}"

            begin
                data = get_request(endpoint)
                @cache.write(cache_key, data, expires_in: ttl)
                results[key] = data
            rescue => e
                Rails.logger.error("Batch fetch error for #{key}: #{e.message}")
            end
        end

        results
    end

    # Cache warming
    def warm_cache(endpoint, cache_key, ttl: 1.hour)
        data = get_request(endpoint)
        @cache.write(cache_key, data, expires_in: ttl)
        data
    end

    # Cache invalidation
    def invalidate_cache(cache_key)
        @cache.delete(cache_key)
    end

    def invalidate_pattern(pattern)
        @cache.delete_matched(pattern)
    end

    private

    def get_request(endpoint)
        response = self.class.get(endpoint, timeout: @timeout)
        raise "API Error: #{response.code}" unless response.success?
        response.parsed_response
    end

    def cacheable?(response)
        response && response['status'] != 'error'
    end

    def refresh_in_background(endpoint, cache_key, fresh_ttl, stale_ttl)
        ApiRefreshJob.perform_later(endpoint, cache_key, cache_key, fresh_ttl, stale_ttl)
    end

    def refresh_cache(endpoint, cache_key, fresh_ttl, stale_ttl)
        data = get_request(endpoint)
        @cache.write("#{cache_key}:fresh", data, expires_in: fresh_ttl)
        @cache.write("#{cache_key}:stale", data, expires_in: stale_ttl)
        data
    end
end
