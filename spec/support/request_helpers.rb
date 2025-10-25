module RequestHelpers
  def json_response
    JSON.parse(response.body)
  end

  def auth_headers(user)
    # Adjust based on your authentication method
    { 'Authorization' => "Bearer #{user.token}" }
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end