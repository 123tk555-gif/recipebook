class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_registration_path, alert: "登録の試行が多すぎます。しばらくしてからやり直してください。" }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "会員登録が完了しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.expect(user: [ :email_address, :display_name, :password, :password_confirmation ])
    end
end
