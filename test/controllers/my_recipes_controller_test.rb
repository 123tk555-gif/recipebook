require "test_helper"

class MyRecipesControllerTest < ActionDispatch::IntegrationTest
  test "ログインが必要" do
    get my_recipes_path
    assert_redirected_to new_session_path
  end

  test "自分のレシピ(非公開を含む)だけが並ぶ" do
    sign_in_as(users(:one))
    get my_recipes_path
    assert_response :success
    assert_select "h2", text: "太郎の公開カレー"
    assert_select "h2", text: "太郎の非公開レシピ"
    assert_select "h2", text: "花子の公開サラダ", count: 0
    assert_select "h2", text: "太郎のゴミ箱レシピ", count: 0
    assert_select "a", /ゴミ箱\(2件\)/
  end
end
