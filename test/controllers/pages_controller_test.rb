require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "利用規約はログインなしで見られる" do
    get terms_path
    assert_response :success
    assert_select "h1", "利用規約"
    assert_select "h2", /禁止事項/
    assert_select "h2", /退会/
    assert_select "a[href=?]", privacy_path
  end

  test "プライバシーポリシーはログインなしで見られる" do
    get privacy_path
    assert_response :success
    assert_select "h1", "プライバシーポリシー"
    assert_select "table.plain-table th[scope=row]", /メールアドレス/
    assert_select "h2", /Cookie/
    assert_select "a[href=?]", terms_path
  end

  test "ログイン中でも見られる" do
    sign_in_as(users(:one))
    get privacy_path
    assert_response :success
  end

  test "連絡先は外部リンクとして、新しいタブで開き、個人情報を書かない注意がある" do
    get terms_path
    assert_select "a[href^='https://github.com/'][target=_blank][rel~=noopener]"
    assert_select "article", /個人情報は書かないでください/
  end

  test "どのページの下にも、規約とポリシーへのリンクがある" do
    [ root_path, new_session_path, terms_path ].each do |path|
      get path
      assert_select "footer a[href=?]", terms_path
      assert_select "footer a[href=?]", privacy_path
    end
  end

  test "会員登録の画面に、同意の案内がある" do
    get new_registration_path
    assert_select "form a[href=?]", terms_path
    assert_select "form a[href=?]", privacy_path
  end
end
