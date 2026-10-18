class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "試行が多すぎます。しばらくしてからやり直してください。" }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))
    if user.nil?
      redirect_to new_session_path, alert: "メールアドレスまたはパスワードが違います。"
    elsif user.suspended?
      redirect_to new_session_path, alert: "このアカウントは利用停止中です。"
    else
      start_new_session_for user
      redirect_to after_authentication_url
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other, notice: "ログアウトしました。"
  end
end
