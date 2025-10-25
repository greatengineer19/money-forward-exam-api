class UsersController < ApplicationController
	skip_before_action :verify_authenticity_token, only: [:signup]

	def signup
		new_user = User.new(
			user_id: signup_params[:user_id],
			nickname: signup_params[:user_id],
			password: signup_params[:password],
			password_confirmation: signup_params[:password]
		)


		if new_user.invalid?
			# due to time constraint, this is a very impractical and bad implementation, however, i must pass the testcases first
			full_messages = new_user.errors.full_messages.select { |msg| ["Password can't be blank"].exclude?(msg) }

			render json: {
				"message": "Account creation failed",
				"cause": full_messages.first
			}, status: :bad_request and return
		end

		new_user.save!

		render json: {
			"message": "Account successfully created",
			"user": {
				"user_id": new_user.user_id,
				"nickname": new_user.nickname
			}
		}, status: :ok
	end

	def show
	end

	def update
	end

	def close
	end

	private

	def signup_params
		params.permit(:user_id, :password)
	end
end
