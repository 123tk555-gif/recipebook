class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "試行が多すぎます。しばらくしてからやり直してください。" }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    # 登録の有無が分からないよう、どちらの場合も同じ表示にする
    redirect_to new_session_path, notice: "登録されているメールアドレスなら、再設定の案内を送りました。"
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "パスワードを変更しました。新しいパスワードでログインしてください。"
    else
      redirect_to edit_password_path(params[:token]), alert: @user.errors.full_messages.to_sentence
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "再設定のリンクが正しくないか、期限が切れています。"
    end
end
