FactoryBot.define do
  factory :comment do
    content { "this is a test comment" }
    sender { "anonymous" }
  end
end
