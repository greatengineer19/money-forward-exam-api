require 'rails_helper'

RSpec.describe "Api::Users", type: :request do
  let(:taro_yamada) { create(:user, user_id: "TaroYamada", password: "PaSSwd4TY", password_confirmation: "PaSSwd4TY") }

  def basic_auth_header(user_id, password)
    credentials = Base64.strict_encode64("#{user_id}:#{password}")

    { 'Authorization' => "Basic #{credentials}"}
  end

  xdescribe "GET /api/posts" do
    it "returns a status ok" do
      create_list(:post, 3)
      
      get "/api/posts"
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /users/:user_id" do
    context 'no nickname' do
      it "returns the user" do
        get "/users/#{taro_yamada.user_id}", headers: basic_auth_header(taro_yamada.user_id, "PaSSwd4TY")

        response_body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(response_body).to eq({"message"=>"User details by user_id", "user"=>{"user_id"=>"TaroYamada", "nickname"=>"TaroYamada"}})
      end
    end
    
    context 'have nickname' do
      before do
        taro_yamada.update!(nickname: "Taro")
      end

      it "returns the user" do
        get "/users/#{taro_yamada.user_id}", headers: basic_auth_header(taro_yamada.user_id, "PaSSwd4TY")

        response_body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(response_body).to eq({"message"=>"User details by user_id", "user"=>{"user_id"=>"TaroYamada", "nickname"=>"Taro", "comment"=>"I'm happy."}})
      end
    end

    context 'no user_id' do
      before do
        taro_yamada.update!(nickname: "Taro")
      end

      it "returns the user" do
        get "/users/any", headers: basic_auth_header(taro_yamada.user_id, "PaSSwd4TY")

        response_body = JSON.parse(response.body)
        expect(response.status).to eql(404)
        expect(response_body).to eq({"message"=>"No user found"})
      end
    end

    context 'no auth' do
      before do
        taro_yamada.update!(nickname: "Taro")
      end

      it "returns the user" do
        get "/users/#{taro_yamada.user_id}"

        response_body = JSON.parse(response.body)
        expect(response.status).to eql(401)
        expect(response_body).to eq({"message"=>"Authentication failed"})
      end
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
    end
    
    context "with invalid parameters, no user id and pw" do
      let(:invalid_attributes) do
        {
          user_id: "",
          password: ""
        }
      end

      it "does not create a new user" do
        expect {
          post "/signup", params: invalid_attributes
        }.to not_change(User, :count)

        response_body = JSON.parse(response.body)
        expect(response_body).to eql({"message"=>"Account creation failed", "cause"=>"Required user_id and password"})
        expect(response.status).to eql(400)
      end
    end

    context "with invalid parameters, user id is used" do
      let(:duplicate_attributes) do
        {
          user_id: "TaroYamada",
          password: "PaSSwd4TY"
        }
      end

      before do
        create(:user, user_id: "TaroYamada", password: "PaSSwd4TY", password_confirmation: "PaSSwd4TY")
      end

      it "does not create a new user" do
        expect {
          post "/signup", params: duplicate_attributes
        }.to not_change(User, :count)

        response_body = JSON.parse(response.body)
        expect(response_body).to eql({"message"=>"Account creation failed", "cause"=>"Already same user_id is used"})
        expect(response.status).to eql(400)
      end
    end
  end

  describe "PATCH /users/:user_id" do
    let(:new_attributes) { { title: 'Updated Title' } }
    
    xit "updates the USER" do
      patch "/api/posts/#{post.id}", params: { post: new_attributes }
      
      post.reload
      expect(response).to have_http_status(:ok)
      expect(post.title).to eq('Updated Title')
    end

    context 'no user_id' do
      before do
        taro_yamada.update!(nickname: "Taro")
      end

      it "no returns the user" do
        patch "/users/any", params: new_attributes, headers: basic_auth_header(taro_yamada.user_id, "PaSSwd4TY")

        response_body = JSON.parse(response.body)
        expect(response.status).to eql(404)
        expect(response_body).to eq({"message"=>"No user found"})
      end
    end

    context 'no auth' do
      before do
        taro_yamada.update!(nickname: "Taro")
      end

      it "returns the user" do
        get "/users/#{taro_yamada.user_id}", params: new_attributes

        response_body = JSON.parse(response.body)
        expect(response.status).to eql(401)
        expect(response_body).to eq({"message"=>"Authentication failed"})
      end
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