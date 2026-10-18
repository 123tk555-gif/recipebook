class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "【レシピ管理】パスワードの再設定", to: user.email_address
  end
end
