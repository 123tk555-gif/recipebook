require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build(overrides = {})
    User.new({ email_address: "new@example.com", display_name: "新人", password: "password123" }.merge(overrides))
  end

  test "有効な会員は保存できる" do
    assert build.valid?
  end

  test "メールアドレスは前後の空白と大文字を直す" do
    assert_equal "new@example.com", build(email_address: "  New@Example.COM ").email_address
  end

  test "メールアドレスは重複できない" do
    assert_not build(email_address: users(:one).email_address).valid?
  end

  test "メールアドレスの形式を確かめる" do
    assert_not build(email_address: "abc").valid?
  end

  test "表示名は必須で30文字まで" do
    assert_not build(display_name: "").valid?
    assert_not build(display_name: "あ" * 31).valid?
    assert build(display_name: "あ" * 30).valid?
  end

  test "パスワードは8文字以上" do
    assert_not build(password: "short12").valid?
  end

  test "会員を消すとレシピも消える" do
    assert_difference "Recipe.count", -users(:one).recipes.count do
      users(:one).destroy!
    end
  end
end
