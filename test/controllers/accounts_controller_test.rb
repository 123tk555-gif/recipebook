require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "ログインが必要" do
    get account_path
    assert_redirected_to new_session_path
  end

  test "表示名を変更できる" do
    sign_in_as(users(:one))
    get account_path
    assert_response :success
    patch account_path, params: { user: { display_name: "たろう" } }
    assert_redirected_to account_path
    assert_equal "たろう", users(:one).reload.display_name
  end

  test "表示名が空だと変更できない。ほかの項目は変えられない" do
    sign_in_as(users(:one))
    patch account_path, params: { user: { display_name: "" } }
    assert_response :unprocessable_entity
    patch account_path, params: { user: { display_name: "たろう", admin: "1", email_address: "x@example.com" } }
    users(:one).reload
    assert_not users(:one).admin?
    assert_equal "one@example.com", users(:one).email_address
  end

  test "パスワードが違うと退会できない" do
    sign_in_as(users(:one))
    assert_no_difference "User.count" do
      delete account_path, params: { password: "wrong", recipes: "delete" }
    end
    assert_redirected_to account_path
  end

  test "退会(公開レシピを残す)" do
    sign_in_as(users(:one))
    assert_difference "User.count", -1 do
      delete account_path, params: { password: "password", recipes: "keep" }
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash", /退会しました/
    assert_select "a", text: "ログイン"
    assert_select ".card", /太郎の公開カレー/
    assert_select ".card", /退会した会員/
  end

  test "退会(すべて削除)" do
    sign_in_as(users(:one))
    delete account_path, params: { password: "password", recipes: "delete" }
    assert_equal 0, Recipe.where(title: "太郎の公開カレー").count
  end

  test "退会したあとは、元のログイン情報で使えない" do
    sign_in_as(users(:one))
    delete account_path, params: { password: "password", recipes: "delete" }
    get new_recipe_path
    assert_redirected_to new_session_path
    post session_path, params: { email_address: "one@example.com", password: "password" }
    assert_redirected_to new_session_path
  end

  test "最後の管理者は退会できない" do
    sign_in_as(users(:admin))
    assert_no_difference "User.count" do
      delete account_path, params: { password: "password", recipes: "delete" }
    end
    follow_redirect!
    assert_select ".flash.alert", /最後の管理者/
  end
end
