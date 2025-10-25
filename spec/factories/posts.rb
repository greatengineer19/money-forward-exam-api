FactoryBot.define do
  factory :post do
    title { Faker::Lorem.sentence(word_count: 5) }
    content { Faker::Lorem.paragraph(sentence_count: 10) }
    published { false }
    association :user
    
    trait :published do
      published { true }
      published_at { Time.current }
    end
    
    trait :with_comments do
      transient do
        comments_count { 2 }
      end
      
      after(:create) do |post, evaluator|
        create_list(:comment, evaluator.comments_count, post_id: post.id)
      end
    end
  end
end