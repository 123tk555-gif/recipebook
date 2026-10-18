require "test_helper"

class RecipeSearchPageTest < ActionDispatch::IntegrationTest
  test "キーワードで検索できる" do
    get recipes_path(q: "サラダ")
    assert_response :success
    assert_select "h2", text: "花子の公開サラダ"
    assert_select "h2", text: "太郎の公開カレー", count: 0
    assert_select "input[name=q][value=?]", "サラダ"
  end

  test "見つからないときは案内を出す" do
    get recipes_path(q: "存在しない料理")
    assert_select "p", /見つかりませんでした/
  end

  test "よく使われるタグから絞り込める" do
    users(:two).recipes.create!(title: "肉じゃが", published: true, tag_list: "和食")
    get recipes_path
    assert_select "nav.tags a", "#和食"

    get recipes_path(tag: "和食")
    assert_select "h2", text: "肉じゃが"
    assert_select "h2", text: "太郎の公開カレー", count: 0
    assert_select "p", /タグ「#和食」で絞り込み中/
  end

  test "おかしな値を送ってもエラーにならない" do
    get recipes_path(sort: "x", max_minutes: "abc", page: "-1", q: "%' OR 1=1 --")
    assert_response :success
  end

  test "次のページへのリンク" do
    21.times { |i| users(:two).recipes.create!(title: "量産#{i}", published: true) }
    get recipes_path(q: "量産")
    assert_select "a[rel=next]"
    get recipes_path(q: "量産", page: 2)
    assert_select "a[rel=prev]"
    assert_select "a[rel=next]", count: 0
  end
end
