class ApiRefreshJob < ApplicationJob
    queue_as :default

    def perform(endpoint, cache_key, fresh_ttl, stale_ttl)
        client = ApiClient.new
        data = client.send(:get_request, endpoint)

        Rails.cache.write("#{cache_key}:fresh", data, expires_in: fresh_ttl)
        Rails.cache.write("#{cache_key}:stale", data, expires_in: stale_ttl)
    rescue => e
        Rails.logger.error("Background refresh failed: #{e.message}")
    end
end