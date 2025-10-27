module CacheHelper
  def with_caching
    original_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original_store
  end
end