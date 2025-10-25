FactoryBot.define do
	factory :user do
		email { Faker::Internet.unique.email }
		password { 'password123' }
		password_confirmation { 'password123' }
		first_name { Faker::Name.first_name }
		last_name { Faker::Name.last_name }

		# PostgreSQL will auto-generate ID via sequence
		# No need to specify ID unless testing specific cases
		
		trait :admin do
			role { 'admin' }
		end

		trait :with_posts do
			transient do
				posts_count { 3 }
			end
			
			after(:create) do |user, evaluator|
				create_list(:post, evaluator.posts_count, user: user)
			end
		end
	end
end