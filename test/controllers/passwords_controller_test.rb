require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "登録済みのメールアドレスには再設定のメールを送る" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "再設定の案内を送りました"
  end

  test "未登録のメールアドレスでも同じ表示で、メールは送らない" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "再設定の案内を送りました"
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "正しくないトークンは受け付けない" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "リンクが正しくないか"
  end

  test "パスワードを変更できる" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "newpassword1", password_confirmation: "newpassword1" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "パスワードを変更しました"
  end

  test "確認用が一致しないと変更できない" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "newpassword1", password_confirmation: "different1" }
      assert_redirected_to edit_password_path(token)
    end
  end

  test "短いパスワードには理由を表示する" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "short", password_confirmation: "short" }
    end
    follow_redirect!
    assert_notice "8文字以上"
  end

  test "メールは日本語で届く" do
    perform_enqueued_jobs do
      post passwords_path, params: { email_address: @user.email_address }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email_address ], mail.to
    assert_match "パスワードの再設定", mail.subject
  end

  private
    def assert_notice(text)
      assert_select ".flash", /#{text}/
    end
end
