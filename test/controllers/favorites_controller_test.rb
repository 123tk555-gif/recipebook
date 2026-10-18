require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  test "ログインなしでは使えない" do
    post recipe_favorite_path(recipes(:public_two))
    assert_redirected_to new_session_path
    get favorites_path
    assert_redirected_to new_session_path
  end

  test "公開レシピをお気に入りに追加・解除でき、件数が変わる" do
    sign_in_as(users(:one))
    recipe = recipes(:public_two)

    assert_difference -> { recipe.reload.favorites_count }, 1 do
      post recipe_favorite_path(recipe)
    end
    assert_redirected_to recipe_path(recipe)
    assert users(:one).favorited?(recipe)

    assert_difference -> { recipe.reload.favorites_count }, -1 do
      delete recipe_favorite_path(recipe)
    end
    assert_not users(:one).favorited?(recipe)
  end

  test "2回追加しても1件だけ" do
    sign_in_as(users(:one))
    recipe = recipes(:public_two)
    assert_difference "Favorite.count", 1 do
      post recipe_favorite_path(recipe)
      post recipe_favorite_path(recipe)
    end
  end

  test "他人の非公開レシピ・ゴミ箱のレシピはお気に入りにできない" do
    sign_in_as(users(:two))
    assert_no_difference "Favorite.count" do
      post recipe_favorite_path(recipes(:private_one))
      assert_response :not_found
      post recipe_favorite_path(recipes(:trashed_one))
      assert_response :not_found
    end
  end

  test "お気に入り一覧には自分のお気に入りだけ、見られなくなったものは出さない" do
    Favorite.create!(user: users(:two), recipe: recipes(:public_one))
    Favorite.create!(user: users(:two), recipe: recipes(:public_two))
    Favorite.create!(user: users(:one), recipe: recipes(:public_two))
    recipes(:public_two).trash!

    sign_in_as(users(:two))
    get favorites_path
    assert_response :success
    assert_select "h2", text: "太郎の公開カレー"
    assert_select "h2", text: "花子の公開サラダ", count: 0
  end

  test "非公開になったレシピはお気に入り一覧から消える" do
    Favorite.create!(user: users(:two), recipe: recipes(:public_one))
    recipes(:public_one).update!(published: false)

    sign_in_as(users(:two))
    get favorites_path
    assert_select "h2", text: "太郎の公開カレー", count: 0
  end

  test "詳細ページにお気に入りボタンと件数が出る" do
    get recipe_path(recipes(:public_two))
    assert_select "a", "ログインしてお気に入りに追加"

    sign_in_as(users(:one))
    get recipe_path(recipes(:public_two))
    assert_select "button", /お気に入りに追加/
    assert_select ".favorite", /お気に入り 0人/
  end

  test "レシピを完全に削除すると、お気に入りも消える" do
    Favorite.create!(user: users(:two), recipe: recipes(:trashed_one))
    assert_difference "Favorite.count", -1 do
      recipes(:trashed_one).destroy!
    end
  end
end
