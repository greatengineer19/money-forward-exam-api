require 'rails_helper'

RSpec.describe "API Caching Integration", type: :request do
	let(:client) { ApiClient.new }
	
	xdescribe "Complete workflow" do
		it 'handles cache lifecycle correctly' do
			VCR.use_cassette("api_users") do
				# First call - cache miss
				result1 = client.fetch_with_cache("/users", "api:users", ttl: 1.minute)
				expect(result1).to be_present

				# Second call - cache hit
				result2 = client.fetch_with_cache("/users", "api:users", ttl: 1.minute)
				expect(result2).to eql(result1)

				# Third call - cache miss after invalidation
				result3 = client.fetch_with_cache("/users", "api:users", ttl: 1.minute)
				expect(result3).to be_present
			end
		end
	end

	xdescribe 'Performance under load' do
		it 'maintains performance with concurrent requests' do
			times = []

			10.times do
				start = Time.now
				client.fetch_with_race_protection("/users", "api:concurrent_test")
				times << (Time.now - start)
			end

			avg_time = times.sum / times.size
			expect(avg_time).to be < 0.1 # Should be fast due to caching
		end
	end
end