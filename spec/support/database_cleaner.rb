RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation, except: %w[ar_internal_metadata])
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  # For tests that use features requiring committed data (e.g., background jobs)
  config.before(:each, type: :feature) do
    DatabaseCleaner.strategy = :truncation
  end
  
  # For tests that specifically need truncation
  config.before(:each, :truncation) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end