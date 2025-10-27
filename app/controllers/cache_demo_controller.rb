class CacheDemoController < ApplicationController
    skip_before_action :verify_authenticity_token

    def index
        @cache_result = flash[:cache_result]
    end

    def cache_klass_demodulize
        Rails.cache.class.name.demodulize
    end

    def set_cache
        # Set a cache with key "demo_key" and value with timestamp
        cache_value = "Cached at #{Time.current}"
        Rails.cache.write('demo_key', cache_value)
        
        flash[:cache_result] = "✓ Cache set successfully: #{cache_value}, #{cache_klass_demodulize}"
        redirect_to cache_demo_path
    end

    def get_cache
        # Get cache from Redis
        cached_value = Rails.cache.read('demo_key')
        
        if cached_value.nil?
        flash[:cache_result] = "✗ Cache not found (nil), #{cache_klass_demodulize}"
        else
        flash[:cache_result] = "✓ Cache retrieved: #{cached_value}, #{cache_klass_demodulize}"
        end
        
        redirect_to cache_demo_path
    end

    def clear_cache
        # Clear the specific cache key
        Rails.cache.delete('demo_key')
        
        flash[:cache_result] = "✓ Cache cleared successfully, #{cache_klass_demodulize}"
        redirect_to cache_demo_path
    end
end
