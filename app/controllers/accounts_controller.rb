# アカウント設定(表示名の変更)と退会
class AccountsController < ApplicationController
  rate_limit to: 10, within: 10.minutes, only: :destroy,
             with: -> { redirect_to account_path, alert: "試行が多すぎます。しばらくしてからやり直してください。" }

  def show
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(params.expect(user: [ :display_name ]))
      redirect_to account_path, notice: "表示名を変更しました。"
    else
      render :show, status: :unprocessable_entity
    end
  end

  # 退会。パスワードで本人確認をしてから行う
  def destroy
    @user = current_user
    unless @user.authenticate(params[:password].to_s)
      redirect_to account_path, alert: "パスワードが違います。退会していません。" and return
    end
    if @user.last_admin?
      redirect_to account_path, alert: "最後の管理者は退会できません。先に別の会員を管理者にしてください。" and return
    end

    keep = params[:recipes] == "keep"
    @user.withdraw!(keep_public_recipes: keep)
    cookies.delete(:session_id)
    reset_session
    redirect_to root_path, status: :see_other,
                notice: keep ? "退会しました。公開中のレシピは「退会した会員」のレシピとして残しました。" : "退会しました。レシピもすべて削除しました。"
  end
end
