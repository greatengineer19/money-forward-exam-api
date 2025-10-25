require 'rails_helper'

RSpec.describe User, type: :model do
  describe "database persistence" do
    it "saves to PostgreSQL" do
      user = create(:user, user_id: 'TaroYamada', password: 'PaSSwd4TY', password_confirmation: 'PaSSwd4TY', nickname: 'Taro', comment: "I'm happy.")
      expect(user.user_id).to be_present
      expect(user.persisted?).to be true
      
      # Verify in database
      db_post = User.find(user.id)
      expect(user.user_id).to eq("TaroYamada")
    end
  end
end
