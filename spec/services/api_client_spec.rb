require 'rails_helper'

RSpec.describe ApiClient, :caching do
	let(:client) { ApiClient.new }
	let(:endpoint) { '/api/v1/users' }
	let(:cache_key) { 'api:users' }
	let(:mock_response) { { 'users' => [{ 'id' => 1, 'name' => 'John' }] }}

	before do
		Rails.cache.clear
		RequestStore.clear!
	end

	describe '#fetch_with_cache' do
		context 'when cache is empty' do
			it 'fetches from API and caches the result' do
				expect(ApiClient).to receive(:get).and_return(
						double(success?: true, parsed_response: mock_response)
				)

				result = client.fetch_with_cache(endpoint, cache_key)
				expect(result).to eql(mock_response)
				expect(Rails.cache.read(cache_key)).to eql(mock_response)
			end
		end

		context 'when cache exists' do
			before do
				Rails.cache.write(cache_key, mock_response)
			end

			it 'returns cached data without API call' do
				expect(ApiClient).not_to receive(:get)

				result = client.fetch_with_cache(endpoint, cache_key)
				expect(result).to eql(mock_response)
			end
		end

		context 'when cache expires' do
			it 'refetches after TTL' do
				Timecop.freeze do
					expect(ApiClient).to receive(:get).and_return(
						double(success?: true, parsed_response: mock_response)
					)

					client.fetch_with_cache(endpoint, cache_key, ttl: 1.minute)

					Timecop.travel(2.minutes.from_now)

					expect(ApiClient).to receive(:get).and_return(
						double(success?: true, parsed_response: mock_response)
					)

					client.fetch_with_cache(endpoint, cache_key, ttl: 1.minute)
				end
			end
		end

		context 'when cache expires 2' do
			before do
				Timecop.freeze

				expect(ApiClient).to receive(:get).and_return(
					double(success?: true, parsed_response: mock_response)
				)

				client.fetch_with_cache(endpoint, cache_key, ttl: 1.minute)
			end

			after do
				Timecop.return
			end

			it 'create cache and then use it when time is not yet expire' do
				Timecop.travel(30.seconds.from_now)

				expect(ApiClient).not_to receive(:get)
				client.fetch_with_cache(endpoint, cache_key, ttl: 1.minute)
			end
		end
	end

	describe '#fetch_with_race_protection' do
		after do
			Timecop.return
		end

		it 'prevents cache stampede with race condition TTL' do
			Timecop.freeze
			Rails.cache.write(cache_key, { data: 'old' }, expires_in: 1.second)
    	Timecop.travel(1.second.from_now)

			call_count = 0
			mutex = Mutex.new
			
			allow(ApiClient).to receive(:get) do
				mutex.synchronize { call_count += 1 }  # Thread-safe!
				Timecop.travel(0.5.second.from_now)
				double(success?: true, parsed_response: mock_response)
			end

			threads = 10.times.map do |i|
				Thread.new do
					Timecop.travel(0.5.second.from_now)
					client.fetch_with_race_protection(endpoint, cache_key)
				end
			end

			threads.each(&:join)

			expect(call_count).to eq(1) 
		end
	end

	describe '#fetch_with_multilevel' do
		it 'checks memory cache first' do
			RequestStore.store["memory:#{cache_key}"] = mock_response

			expect(Rails.cache).not_to receive(:fetch)
			result = client.fetch_with_multilevel(endpoint, cache_key)

			expect(result).to eql(mock_response)
		end

		it 'checks Redis cache second' do
			Rails.cache.write(cache_key, mock_response)

			result = client.fetch_with_multilevel(endpoint, cache_key)

			expect(result).to eql(mock_response)
			expect(RequestStore.store["memory:#{cache_key}"]).to eql(mock_response)
		end

		it 'fetches from API if no cache exists' do
			expect(ApiClient).to receive(:get).and_return(
				double(success?: true, parsed_response: mock_response)
			)

			result = client.fetch_with_multilevel(endpoint, cache_key)

			expect(result).to eql(mock_response)
			expect(Rails.cache.read(cache_key)).to eql(mock_response)
			expect(RequestStore.store["memory:#{cache_key}"]).to eql(mock_response)
		end
	end

	describe '#fetch_with_conditional_cache' do
		it 'caches successful responses' do
			response = { 'status' => 'success', 'data' => 'test' }
			expect(ApiClient).to receive(:get).and_return(
				double(success?: true, parsed_response: response)
			)

			result = client.fetch_with_conditional_cache(endpoint, cache_key)
			expect(Rails.cache.read(cache_key)).to eql(response)
		end

		it 'does not cache error responses' do
			response = { 'status' => 'error', 'message' => 'failed' }

			expect(ApiClient).to receive(:get).and_return(
				double(success?: true, parsed_response: response)
			)

			result = client.fetch_with_conditional_cache(endpoint, cache_key)
			expect(Rails.cache.read(cache_key)).to be_nil
		end
	end

	describe '#fetch_with_etag' do
		context 'when ETag matches (304 Not Modified)' do
			it 'returns cached data' do
				Rails.cache.write(cache_key, mock_response)
				Rails.cache.write("#{cache_key}:etag", "etag123")

				expect(ApiClient).to receive(:get).with(
					endpoint,
					hash_including(headers: { 'If-None-Match' => 'etag123' })
				).and_return(double(code: 304 ))

				result = client.fetch_with_etag(endpoint, cache_key)
				expect(result).to eql(mock_response)
			end
		end

		context 'when ETag does not match' do
			it 'fetches new data and updates cache' do
				new_response = { 'users' => [{ 'id' => 2, 'name' => 'Jane' }] }

				expect(ApiClient).to receive(:get).and_return(
					double(
						code: 200,
						parsed_response: new_response,
						headers: { 'etag' => 'etag456' }
					)
				)

				result = client.fetch_with_etag(endpoint, cache_key)

				expect(result).to eql(new_response)
				expect(Rails.cache.read(cache_key)).to eql(new_response)
				expect(Rails.cache.read("#{cache_key}:etag")).to eql('etag456')
			end
		end

		context 'when API fails' do
			it 'falls back to cached data' do
				Rails.cache.write(cache_key, mock_response)

				expect(ApiClient).to receive(:get).and_raise(StandardError.new('API down'))
			
				result = client.fetch_with_etag(endpoint, cache_key)
				expect(result).to eql(mock_response)
			end
		end
	end

	describe '#fetch_with_last_modified' do
		it 'uses If-Modified-Since header' do
			last_mod = Time.now.httpdate
			Rails.cache.write(cache_key, mock_response)
			Rails.cache.write("#{cache_key}:last_modified", last_mod)

			expect(ApiClient).to receive(:get).with(
				endpoint,
				hash_including(headers: { 'If-Modified-Since' => last_mod})
			).and_return(double(code: 304))

			result = client.fetch_with_last_modified(endpoint, cache_key)
			expect(result).to eql(mock_response)
		end
	end

	describe '#fetch_with_swr' do
		it 'returns fresh cache immediately' do
			Rails.cache.write("#{cache_key}:fresh", mock_response)

			expect(ApiClient).not_to receive(:get)
			result = client.fetch_with_swr(endpoint, cache_key)
			expect(result).to eql(mock_response)
		end

		it 'returns stale cache and refreshes in background' do
			Rails.cache.write("#{cache_key}:stale", mock_response)

			expect(ApiRefreshJob).to receive(:perform_later)

			result = client.fetch_with_swr(endpoint, cache_key)
			expect(result).to eql(mock_response)
		end

		it 'fetches synchronously when no cache exists' do
			expect(ApiClient).to receive(:get).and_return(
				double(success?: true, parsed_response: mock_response)
			)

			result = client.fetch_with_swr(endpoint, cache_key)
			expect(result).to eql(mock_response)
		end
	end

	describe '#fetch_with_fallback_chain' do
		let(:endpoints) { ['/api/v1/primary', '/api/v2/backup', '/api/v3/fallback' ]}

		it 'returns from first successful endpoint' do
			expect(ApiClient).to receive(:get).with('/api/v1/primary', anything).and_return(
				double(success?: true, parsed_response: mock_response)
			)

			result = client.fetch_with_fallback_chain(endpoints, cache_key)
			expect(result).to eql(mock_response)
		end

		it 'tries backup endpoint if primary fails' do
			expect(ApiClient).to receive(:get).with("/api/v1/primary", anything)
				.and_raise(StandardError.new("Primary down"))

			expect(ApiClient).to receive(:get).with("/api/v2/backup", anything).and_return(
				double(success?: true, parsed_response: mock_response)
			)

			result = client.fetch_with_fallback_chain(endpoints, cache_key)
			expect(result).to eql(mock_response)
		end

		it 'raises error if all endpoints fail' do
			endpoints.each do |ep|
				expect(ApiClient).to receive(:get).with(ep, anything)
					.and_raise(StandardError.new("Failed"))
			end

			expect {
				client.fetch_with_fallback_chain(endpoints, cache_key)
			}.to raise_error(RuntimeError, "All endpoints failed")
		end
	end

	describe "#fetch_batch" do
		let(:endpoint_map) do
			{
				'user1' => "/api/users/1",
				"user2" => "/api/users/2",
				"user3" => "/api/users/3"
			}
		end

		it 'fetches uncached items and returns all results' do
			Rails.cache.write("batch:user1", { 'id' => 1 })

			expect(ApiClient).to receive(:get).with("/api/users/2", anything).and_return(
				double(success?: true, parsed_response: { 'id' => 2 })
			)

			expect(ApiClient).to receive(:get).with("/api/users/3", anything).and_return(
				double(success?: true, parsed_response: { 'id' => 3 })
			)

			results = client.fetch_batch(endpoint_map, 'batch')

			expect(results['user1']).to eql({ 'id' => 1 })
			expect(results['user2']).to eql({ 'id' => 2 })
			expect(results['user3']).to eql({ 'id' => 3 })
		end

		it 'continues on individual failures' do
			expect(ApiClient).to receive(:get).with("/api/users/1", anything).and_return(
				double(success?: true, parsed_response: { "id" => 1 })
			)

			expect(ApiClient).to receive(:get).with("/api/users/2", anything)
				.and_raise(StandardError.new("Failed"))

			expect(ApiClient).to receive(:get).with("/api/users/3", anything).and_return(
				double(success?: true, parsed_response: { 'id' => 3 })
			)

			results = client.fetch_batch(endpoint_map, 'batch')

			expect(results['user1']).to eql({ 'id' => 1 })
			expect(results['user2']).to be_nil
			expect(results['user3']).to eql({ 'id' => 3 })
		end
	end

	describe '#warm_cache' do
		it 'fetches data and stores in cache' do
			expect(ApiClient).to receive(:get).and_return(
				double(success?: true, parsed_response: mock_response)
			)

			result = client.warm_cache(endpoint, cache_key)

			expect(result).to eql(mock_response)
			expect(Rails.cache.read(cache_key)).to eql(mock_response)
		end
	end

	describe "#invalidate_cache" do
		it 'deletes cache entry' do
			Rails.cache.write(cache_key, mock_response)

			client.invalidate_cache(cache_key)

			expect(Rails.cache.read(cache_key)).to be_nil
		end
	end

	describe "#invalidate_pattern" do
		it 'deletes all matching cache entries' do
			Rails.cache.write("api:users:1", { id: 1 })
			Rails.cache.write("api:users:2", { id: 2 })
			Rails.cache.write("api:posts:1", { id: 1 })

			client.invalidate_pattern("api:users:*")

			expect(Rails.cache.read("api:users:1")).to be_nil
			expect(Rails.cache.read("api:users:2")).to be_nil
			expect(Rails.cache.read("api:posts:1")).not_to be_nil
		end
	end
end