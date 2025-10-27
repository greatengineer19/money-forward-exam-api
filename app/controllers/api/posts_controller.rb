class Api::PostsController < ApplicationController
  before_action :set_post, only: %i[show update destroy]
  skip_before_action :verify_authenticity_token

  # def index
  #   user_yamada = User.find_by(user_id: "TaroYamada")
	# 	if user_yamada.nil?
	# 		user_yamada = User.new(
	# 			user_id: "TaroYamada",
	# 			password: "PaSSwd4TY",
	# 			password_confirmation: "PaSSwd4TY"
	# 		)
	# 		user_yamada.save
	# 	end
  
  #   @posts = Post.includes(:user).order(created_at: :desc).page(params[:page])
  # end

  def index
    render json: {
      status: 'ok',
      message: 'Money Forward API is running',
      timestamp: Time.current.iso8601,
      version: '1.0.0'
    }, status: :ok
  end

  def new
    @post = Post.new
  end

  def show
    render json: @post
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to api_post_path(@post), notice: "Post was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      render json: @post
    else
      render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    head :no_content
  end

  private

  def set_post
    @post = Post.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Post not found' }, status: :not_found
  end

  def post_params
    params.require(:post).permit(:title, :content, :published, :user_id)
  end
end
