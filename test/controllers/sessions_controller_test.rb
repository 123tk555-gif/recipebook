require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "正しい情報でログインできる" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "パスワードが違うとログインできない" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "利用停止中の会員はログインできない" do
    post session_path, params: { email_address: users(:suspended).email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    follow_redirect!
    assert_select ".flash.alert", /利用停止/
  end

  test "ログイン後に利用停止になると、使い続けられない" do
    sign_in_as(@user)
    get new_recipe_path
    assert_response :success

    @user.update!(suspended: true)
    get new_recipe_path
    assert_redirected_to new_session_path
  end

  test "ログアウトできる" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
