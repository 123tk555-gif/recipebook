require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def valid_params(overrides = {})
    { user: { email_address: "new@example.com", display_name: "新人", password: "password123", password_confirmation: "password123" }.merge(overrides) }
  end

  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "会員登録するとログイン状態になる" do
    assert_difference "User.count", 1 do
      post registration_path, params: valid_params
    end
    assert_redirected_to root_path
    assert cookies[:session_id]
    assert_not User.find_by(email_address: "new@example.com").admin?
  end

  test "管理者や停止の指定は受け付けない" do
    post registration_path, params: valid_params.deep_merge(user: { admin: "1", suspended: "1" })
    user = User.find_by(email_address: "new@example.com")
    assert_not user.admin?
    assert_not user.suspended?
  end

  test "入力が正しくないと登録されない" do
    assert_no_difference "User.count" do
      post registration_path, params: valid_params(password_confirmation: "different")
    end
    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "同じメールアドレスでは登録できない" do
    assert_no_difference "User.count" do
      post registration_path, params: valid_params(email_address: users(:one).email_address)
    end
    assert_response :unprocessable_entity
  end
end
