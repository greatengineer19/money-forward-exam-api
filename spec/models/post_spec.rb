require 'rails_helper'

RSpec.describe Post, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:comments).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }
    it { should validate_length_of(:title).is_at_most(255) }
  end

  describe "database persistence" do
    it "saves to PostgreSQL with auto-generated ID" do
      user = create(:user)
      post = Post.create!(
        title: "Test Post",
        content: "Test Content",
        user: user
      )
      
      expect(post.id).to be_present
      expect(post.persisted?).to be true
      
      # Verify in database
      db_post = Post.find(post.id)
      expect(db_post.title).to eq("Test Post")
    end
    
    it "uses PostgreSQL sequences for ID generation" do
      user = create(:user)
      post1 = create(:post, user: user)
      post2 = create(:post, user: user)
      
      expect(post2.id).to be > post1.id
    end
  end

  describe "scopes" do
    let!(:published_post) { create(:post, :published) }
    let!(:draft_post) { create(:post, published: false) }
    
    it "returns only published posts" do
      expect(Post.published).to include(published_post)
      expect(Post.published).not_to include(draft_post)
    end
  end

  describe "#publish!" do
    let(:post) { create(:post, published: false) }
    
    it "marks the post as published" do
      post.publish!
      
      expect(post.published).to be true
      expect(post.published_at).to be_present
    end
    
    it "persists published state to database" do
      post.publish!
      
      # Reload from database
      post.reload
      expect(post.published).to be true
    end
  end
end