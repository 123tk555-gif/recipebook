require "test_helper"

class TrashedRecipesControllerTest < ActionDispatch::IntegrationTest
  test "ログインが必要" do
    get trashed_recipes_path
    assert_redirected_to new_session_path
  end

  test "自分のゴミ箱だけが見える" do
    sign_in_as(users(:one))
    get trashed_recipes_path
    assert_response :success
    assert_select "li", /太郎のゴミ箱レシピ/
    assert_select "li", /あと27日/
    assert_select "li", text: /花子/, count: 0
  end

  test "元に戻せる" do
    sign_in_as(users(:one))
    recipe = recipes(:trashed_one)
    post restore_trashed_recipe_path(recipe)
    assert_redirected_to recipe_path(recipe)
    assert_not recipe.reload.trashed?
  end

  test "完全に削除できる" do
    sign_in_as(users(:one))
    assert_difference "Recipe.count", -1 do
      delete trashed_recipe_path(recipes(:trashed_one))
    end
  end

  test "ゴミ箱を空にできる(他人のものは消えない)" do
    recipes(:public_two).trash!
    sign_in_as(users(:one))
    assert_difference "Recipe.count", -2 do
      delete empty_trashed_recipes_path
    end
    assert Recipe.exists?(recipes(:public_two).id)
  end

  test "ゴミ箱に入っていないレシピは操作できない" do
    sign_in_as(users(:one))
    delete trashed_recipe_path(recipes(:public_one))
    assert_response :not_found
    post restore_trashed_recipe_path(recipes(:public_one))
    assert_response :not_found
  end

  test "他人のゴミ箱は操作できない" do
    recipes(:public_two).trash!
    sign_in_as(users(:one))
    delete trashed_recipe_path(recipes(:public_two))
    assert_response :not_found
    post restore_trashed_recipe_path(recipes(:public_two))
    assert_response :not_found
  end
end
