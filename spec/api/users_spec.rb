require 'rails_helper'

RSpec.describe "Api::Users", type: :request do
  xdescribe "GET /api/posts" do
    it "returns a status ok" do
      create_list(:post, 3)
      
      get "/api/posts"
      
      expect(response).to have_http_status(:ok)
    end
  end

  xdescribe "GET /api/posts/:id" do
    let(:post) { create(:post) }
    
    it "returns the post" do
      get "/api/posts/#{post.id}"
      
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(post.id)
      expect(json_response['title']).to eq(post.title)
    end
    
    it "returns 404 when post not found" do
      get "/api/posts/999999"
      
      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to eq('Post not found')
    end
  end

  describe "POST /signup" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          user_id: "TaroYamada",
          password: "PaSSwd4TY"
        }
      end

      it "creates a new user" do
        expect {
          post "/signup", params: valid_attributes
        }.to change(User, :count).by(1)

        response_body = JSON.parse(response.body)
        expect(response_body).to eql({"message"=>"Account successfully created", "user"=>{"user_id"=>"TaroYamada", "nickname"=>"TaroYamada"}})
        expect(response.status).to eql(200)
      end
      
      xit "persists data to PostgreSQL" do
        post "/api/posts", params: { post: valid_attributes }
        
        created_post = Post.last
        expect(created_post.title).to eq('Test Post')
        expect(created_post.user_id).to eq(user.id)
      end
    end
    
    xcontext "with invalid parameters" do
      it "does not create a new post" do
        expect {
          post "/api/posts", params: { post: invalid_attributes }
        }.not_to change(Post, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  xdescribe "PATCH /api/posts/:id" do
    let(:post) { create(:post) }
    let(:new_attributes) { { title: 'Updated Title' } }
    
    it "updates the post" do
      patch "/api/posts/#{post.id}", params: { post: new_attributes }
      
      post.reload
      expect(response).to have_http_status(:ok)
      expect(post.title).to eq('Updated Title')
    end
    
    it "persists updates to PostgreSQL" do
      original_title = post.title
      patch "/api/posts/#{post.id}", params: { post: new_attributes }
      
      # Verify change persisted in database
      updated_post = Post.find(post.id)
      expect(updated_post.title).to eq('Updated Title')
      expect(updated_post.title).not_to eq(original_title)
    end
    
    it "returns errors for invalid data" do
      patch "/api/posts/#{post.id}", params: { post: { title: '' } }
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  xdescribe "DELETE /api/posts/:id" do
    let!(:post) { create(:post, :with_comments) }

    before do
      expect(post.comments.size).to eql(2)
    end
    
    it "deletes the post" do
      expect {
        delete "/api/posts/#{post.id}"
      }.to change(Post, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
    
    it "removes record from PostgreSQL" do
      post_id = post.id
      delete "/api/posts/#{post_id}"
      
      expect(Post.exists?(post_id)).to be false
    end
  end
end