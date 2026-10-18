require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  def recipe_params(overrides = {})
    { recipe: { title: "ナポリタン", description: "喫茶店風", cooking_minutes: 20, servings: 2,
                published: "1", tag_list: "パスタ, 簡単",
                ingredients_attributes: { "0" => { name: "パスタ", quantity: "200g", position: 0 },
                                          "1" => { name: "", quantity: "" } },
                steps_attributes: { "0" => { body: "茹でる", position: 0 } } }.merge(overrides) }
  end

  # --- 閲覧 ---
  test "一覧はログインなしで公開レシピだけ見られる" do
    get recipes_path
    assert_response :success
    assert_select "h2", text: "太郎の公開カレー"
    assert_select "h2", text: "花子の公開サラダ"
    assert_select "h2", text: "太郎の非公開レシピ", count: 0
    assert_select "h2", text: "太郎のゴミ箱レシピ", count: 0
  end

  test "公開レシピはログインなしで詳細を見られる" do
    get recipe_path(recipes(:public_one))
    assert_response :success
    assert_select "h1", "太郎の公開カレー"
    assert_select "li", /米/
    assert_select "ol li", "野菜を切る"
  end

  test "非公開レシピは他人とログインなしには存在しないものとして扱う" do
    get recipe_path(recipes(:private_one))
    assert_response :not_found

    sign_in_as(users(:two))
    get recipe_path(recipes(:private_one))
    assert_response :not_found
  end

  test "非公開レシピは持ち主なら見られる" do
    sign_in_as(users(:one))
    get recipe_path(recipes(:private_one))
    assert_response :success
  end

  test "ゴミ箱のレシピは持ち主だけが見られ、注意が表示される" do
    get recipe_path(recipes(:trashed_one))
    assert_response :not_found

    sign_in_as(users(:one))
    get recipe_path(recipes(:trashed_one))
    assert_response :success
    assert_select ".flash.alert", /ゴミ箱/
  end

  test "説明文のHTMLは無害化される" do
    recipes(:public_one).update!(description: "<script>alert(1)</script>")
    get recipe_path(recipes(:public_one))
    assert_select "script", text: /alert/, count: 0
  end

  # --- 登録 ---
  test "ログインなしでは書けない" do
    get new_recipe_path
    assert_redirected_to new_session_path
    assert_no_difference "Recipe.count" do
      post recipes_path, params: recipe_params
    end
    assert_redirected_to new_session_path
  end

  test "new" do
    sign_in_as(users(:one))
    get new_recipe_path
    assert_response :success
    assert_select "input[name='recipe[title]']"
  end

  test "レシピを登録できる(空の材料行は無視、タグ付き)" do
    sign_in_as(users(:one))
    assert_difference [ "Recipe.count" ], 1 do
      post recipes_path, params: recipe_params
    end
    recipe = Recipe.order(:id).last
    assert_redirected_to recipe_path(recipe)
    assert_equal users(:one), recipe.user
    assert_equal 1, recipe.ingredients.count
    assert_equal 1, recipe.steps.count
    assert_equal %w[パスタ 簡単], recipe.tags.map(&:name).sort
    assert recipe.published?
  end

  test "持ち主は常にログイン中の会員(user_id を送っても無視)" do
    sign_in_as(users(:one))
    post recipes_path, params: recipe_params(user_id: users(:two).id)
    assert_equal users(:one), Recipe.order(:id).last.user
  end

  test "料理名が空だと登録できない" do
    sign_in_as(users(:one))
    assert_no_difference "Recipe.count" do
      post recipes_path, params: recipe_params(title: "")
    end
    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "写真を付けて登録できる" do
    sign_in_as(users(:one))
    png = fixture_file_upload("pixel.png", "image/png")
    assert_difference "ActiveStorage::Attachment.count", 1 do
      post recipes_path, params: recipe_params(photo: png)
    end
    assert Recipe.order(:id).last.photo.attached?
  end

  test "写真以外のファイルは受け付けない" do
    sign_in_as(users(:one))
    txt = fixture_file_upload("note.txt", "image/png")
    assert_no_difference "Recipe.count" do
      post recipes_path, params: recipe_params(photo: txt)
    end
    assert_response :unprocessable_entity
  end

  # --- 編集 ---
  test "自分のレシピを編集・更新できる" do
    sign_in_as(users(:one))
    recipe = recipes(:public_one)
    get edit_recipe_path(recipe)
    assert_response :success

    patch recipe_path(recipe), params: { recipe: { title: "辛口カレー", published: "0" } }
    assert_redirected_to recipe_path(recipe)
    assert_equal "辛口カレー", recipe.reload.title
    assert_not recipe.published?
  end

  test "材料を削除・追加できる" do
    sign_in_as(users(:one))
    recipe = recipes(:public_one)
    patch recipe_path(recipe), params: { recipe: {
      ingredients_attributes: { "0" => { id: ingredients(:curry_rice).id, _destroy: "1" },
                                "1" => { name: "福神漬け", quantity: "適量", position: 5 } } } }
    assert_equal [ "カレールー", "福神漬け" ], recipe.reload.ingredients.map(&:name)
  end

  test "他人のレシピは編集・更新できない(404)" do
    sign_in_as(users(:two))
    recipe = recipes(:public_one)
    get edit_recipe_path(recipe)
    assert_response :not_found
    patch recipe_path(recipe), params: { recipe: { title: "乗っ取り" } }
    assert_response :not_found
    assert_equal "太郎の公開カレー", recipe.reload.title
  end

  test "他人の材料を自分のレシピ経由で書き換えられない" do
    sign_in_as(users(:two))
    mine = recipes(:public_two)
    patch recipe_path(mine), params: { recipe: { ingredients_attributes: { "0" => { id: ingredients(:curry_rice).id, name: "改ざん" } } } }
    assert_equal "米", ingredients(:curry_rice).reload.name
  end

  # --- 削除(ゴミ箱) ---
  test "削除するとゴミ箱に移る" do
    sign_in_as(users(:one))
    recipe = recipes(:public_one)
    assert_no_difference "Recipe.count" do
      delete recipe_path(recipe)
    end
    assert_redirected_to my_recipes_path
    assert recipe.reload.trashed?
    get recipes_path
    assert_select "h2", text: "太郎の公開カレー", count: 0
  end

  test "他人のレシピは削除できない" do
    sign_in_as(users(:two))
    delete recipe_path(recipes(:public_one))
    assert_response :not_found
    assert_not recipes(:public_one).reload.trashed?
  end

  test "ログインなしでは削除できない" do
    delete recipe_path(recipes(:public_one))
    assert_redirected_to new_session_path
  end
end
