require "test_helper"

class RecipeSearchTest < ActiveSupport::TestCase
  def titles(**params)
    RecipeSearch.new(**params).results.map(&:title)
  end

  def create_recipe(title:, user: users(:two), **attrs)
    user.recipes.create!(title: title, published: true, **attrs)
  end

  test "条件なしは公開レシピだけを新しい順に" do
    result = titles
    assert_includes result, "太郎の公開カレー"
    assert_includes result, "花子の公開サラダ"
    assert_not_includes result, "太郎の非公開レシピ"
    assert_not_includes result, "太郎のゴミ箱レシピ"
    newest = create_recipe(title: "いちばん新しい")
    assert_equal newest.title, titles.first
  end

  test "料理名で探せる" do
    assert_equal [ "太郎の公開カレー" ], titles(q: "カレー")
  end

  test "材料名で探せる" do
    assert_equal [ "太郎の公開カレー" ], titles(q: "米")
  end

  test "タグ名で探せる" do
    create_recipe(title: "トマト煮", tag_list: "イタリアン")
    assert_equal [ "トマト煮" ], titles(q: "イタリア")
  end

  test "空白で区切ると、すべての語を含むものに絞る" do
    create_recipe(title: "トマトパスタ", ingredients_attributes: [ { name: "にんにく" } ])
    create_recipe(title: "トマトサラダ")
    assert_equal [ "トマトパスタ" ], titles(q: "トマト　にんにく")
  end

  test "非公開・ゴミ箱のレシピは検索に出ない" do
    assert_empty titles(q: "非公開")
    assert_empty titles(q: "ゴミ箱")
  end

  test "% や _ はそのままの文字として探す" do
    create_recipe(title: "100%ジュース")
    assert_equal [ "100%ジュース" ], titles(q: "100%")
    assert_empty titles(q: "_")
  end

  test "タグで絞り込める(全角・大文字も同じタグ)" do
    create_recipe(title: "簡単オムレツ", tag_list: "easy")
    assert_equal [ "簡単オムレツ" ], titles(tag: "ＥＡＳＹ")
  end

  test "調理時間で絞り込める" do
    create_recipe(title: "10分丼", cooking_minutes: 10)
    create_recipe(title: "時間未設定")
    result = titles(max_minutes: 15)
    assert_equal [ "10分丼" ], result
  end

  test "決められた以外の調理時間・並び順は無視する" do
    search = RecipeSearch.new(max_minutes: 7, sort: "drop table")
    assert_nil search.max_minutes
    assert_equal "new", search.sort
  end

  test "お気に入りが多い順" do
    popular = create_recipe(title: "人気")
    Favorite.create!(user: users(:one), recipe: popular)
    assert_equal "人気", titles(sort: "popular").first
  end

  test "調理時間が短い順(未設定は最後)" do
    create_recipe(title: "5分", cooking_minutes: 5)
    create_recipe(title: "未設定")
    result = titles(sort: "quick")
    assert_equal "5分", result.first
    assert_equal "太郎の公開カレー", result[1]
    assert_operator result.index("未設定"), :>, result.index("太郎の公開カレー")
  end

  test "ページ分け" do
    (RecipeSearch::PER_PAGE + 1).times { |i| create_recipe(title: "量産#{i}") }
    first = RecipeSearch.new(q: "量産")
    assert_equal RecipeSearch::PER_PAGE, first.results.size
    assert first.next_page?
    assert_not first.prev_page?

    second = RecipeSearch.new(q: "量産", page: 2)
    assert_equal 1, second.results.size
    assert_not second.next_page?
    assert second.prev_page?
  end

  test "ページ番号は1以上" do
    assert_equal 1, RecipeSearch.new(page: -3).page
    assert_equal 1, RecipeSearch.new(page: "abc").page
  end
end
