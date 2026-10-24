require "test_helper"

# 材料・手順の枠を、ボタンで増やしたり減らしたりする機能のサーバー側
class RecipeRowsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  def rows(prefix, count, key)
    (0...count).to_h { |i| [ (1000 + i * 7).to_s, { key => "#{prefix}#{i + 1}", position: i } ] }
  end

  # --- 画面 ---
  test "新しいレシピのフォームには、追加ボタンと、ひな形と、削除ボタンがある" do
    get new_recipe_path
    assert_select "fieldset[data-controller=nested-form][data-nested-form-name-value=材料]", 1
    assert_select "fieldset[data-controller=nested-form][data-nested-form-name-value=手順]", 1
    assert_select "button[data-action='nested-form#add']", 2
    assert_select "button[data-nested-form-target=addButton]", text: /材料の枠を追加/
    assert_select "button[data-nested-form-target=addButton]", text: /手順の枠を追加/
    # 最初の枠は3つずつ。それぞれに削除ボタンがある
    assert_select "[data-nested-form-target=list] .ingredient-row", 3
    assert_select "[data-nested-form-target=list] .step-row", 3
    assert_select "[data-nested-form-target=list] button[data-action='nested-form#remove']", 6
    # 結果を文字で知らせる場所
    assert_select "[role=status][aria-live=polite][data-nested-form-target=status]", 2
  end

  test "ひな形(template)の中の入力欄は、番号が NEW_RECORD になっていて、送信されない場所にある" do
    get new_recipe_path
    assert_select "template[data-nested-form-target=template]", 2
    assert_select "template input[name='recipe[ingredients_attributes][NEW_RECORD][name]']", 1
    assert_select "template textarea[name='recipe[steps_attributes][NEW_RECORD][body]']", 1
  end

  test "上限の数が画面に出る" do
    get new_recipe_path
    assert_select "legend", /材料\(#{Recipe::MAX_INGREDIENTS}個まで\)/
    assert_select "legend", /作り方\(#{Recipe::MAX_STEPS}手順まで\)/
    assert_select "fieldset[data-nested-form-name-value=材料][data-nested-form-max-value='#{Recipe::MAX_INGREDIENTS}']", 1
    assert_select "fieldset[data-nested-form-name-value=手順][data-nested-form-max-value='#{Recipe::MAX_STEPS}']", 1
  end

  test "編集では、保存済みの枠の id が枠の中に入っている(削除に必要)" do
    get edit_recipe_path(recipes(:public_one))
    assert_select ".ingredient-row input[type=hidden][name$='[id]']", 2
    assert_select ".step-row input[type=hidden][name$='[id]']", 2
    # 保存済み2 + 空き1(ひな形の中の1つは、別に数える)
    assert_select "[data-nested-form-target=list] .ingredient-row input[name$='[_destroy]'][value='0']", 3
    assert_select "template .ingredient-row", 1
  end

  # --- 保存 ---
  test "ボタンで増やした枠(送られる番号がばらばら)も、決めた並びで保存される" do
    assert_difference "Recipe.count", 1 do
      post recipes_path, params: { recipe: {
        title: "たくさんの材料", published: "1",
        ingredients_attributes: rows("材料", 12, :name),
        steps_attributes: rows("手順", 9, :body)
      } }
    end
    recipe = Recipe.order(:id).last
    assert_equal (1..12).map { |i| "材料#{i}" }, recipe.ingredients.map(&:name)
    assert_equal (1..9).map { |i| "手順#{i}" }, recipe.steps.map(&:body)
  end

  test "枠の並びは position の順になる" do
    post recipes_path, params: { recipe: { title: "並び", ingredients_attributes: {
      "5" => { name: "二番目", position: 1 }, "9" => { name: "三番目", position: 2 }, "1" => { name: "最初", position: 0 }
    } } }
    assert_equal %w[最初 二番目 三番目], Recipe.order(:id).last.ingredients.map(&:name)
  end

  test "保存済みの枠を削除(_destroy=1)すると、保存のときに消え、残りの並びは保たれる" do
    recipe = recipes(:public_one)
    patch recipe_path(recipe), params: { recipe: {
      ingredients_attributes: {
        "0" => { id: ingredients(:curry_rice).id, name: "米", position: 0, _destroy: "1" },
        "1" => { id: ingredients(:curry_roux).id, name: "カレールー", position: 1, _destroy: "0" },
        "1001" => { name: "福神漬け", quantity: "適量", position: 2, _destroy: "0" }
      },
      steps_attributes: {
        "0" => { id: steps(:curry_step_one).id, body: "野菜を切る", position: 0, _destroy: "0" },
        "1" => { id: steps(:curry_step_two).id, body: "煮込む", position: 1, _destroy: "1" }
      }
    } }
    assert_redirected_to recipe_path(recipe)
    recipe.reload
    assert_equal %w[カレールー 福神漬け], recipe.ingredients.map(&:name)
    assert_equal %w[野菜を切る], recipe.steps.map(&:body)
  end

  test "空の枠は無視される(足しすぎた枠をそのままにしても大丈夫)" do
    post recipes_path, params: { recipe: { title: "空の枠", ingredients_attributes: {
      "0" => { name: "塩", quantity: "少々", position: 0 }, "1" => { name: "", quantity: "", position: 1 },
      "2" => { name: "", quantity: "", position: 2 }
    } } }
    assert_equal %w[塩], Recipe.order(:id).last.ingredients.map(&:name)
  end

  # --- 上限 ---
  test "材料が上限(50個)ちょうどなら保存できる" do
    assert_difference "Recipe.count", 1 do
      post recipes_path, params: { recipe: { title: "50個", ingredients_attributes: rows("材料", Recipe::MAX_INGREDIENTS, :name) } }
    end
    assert_equal Recipe::MAX_INGREDIENTS, Recipe.order(:id).last.ingredients.count
  end

  test "材料が上限を超えると保存されず、理由と、入力した内容を表示する" do
    assert_no_difference "Recipe.count" do
      post recipes_path, params: { recipe: { title: "多すぎる", ingredients_attributes: rows("材料", Recipe::MAX_INGREDIENTS + 1, :name) } }
    end
    assert_response :unprocessable_entity
    assert_select ".errors", /材料は 50 個までです/
    assert_select "input[name$='[name]'][value='材料51']"
  end

  test "手順が上限を超えると保存されない" do
    assert_no_difference "Recipe.count" do
      post recipes_path, params: { recipe: { title: "多すぎる", steps_attributes: rows("手順", Recipe::MAX_STEPS + 1, :body) } }
    end
    assert_response :unprocessable_entity
    assert_select ".errors", /作り方は|手順は/
  end

  test "削除する枠は、上限の数に入らない" do
    recipe = users(:one).recipes.create!(title: "ぎりぎり", ingredients_attributes: rows("材料", Recipe::MAX_INGREDIENTS, :name))
    ids = recipe.ingredients.map(&:id)
    attrs = ids.each_with_index.to_h { |id, i| [ i.to_s, { id: id, name: "材料#{i + 1}", position: i, _destroy: (i == 0 ? "1" : "0") } ] }
    attrs["900"] = { name: "新しい材料", position: 50, _destroy: "0" }
    patch recipe_path(recipe), params: { recipe: { ingredients_attributes: attrs } }
    assert_redirected_to recipe_path(recipe)
    assert_equal Recipe::MAX_INGREDIENTS, recipe.reload.ingredients.count
  end

  test "入力ミスで描き直したとき、取り消した枠は隠れたまま(_destroy=1)で戻ってくる" do
    recipe = recipes(:public_one)
    patch recipe_path(recipe), params: { recipe: {
      title: "",
      ingredients_attributes: {
        "0" => { id: ingredients(:curry_rice).id, name: "米", position: 0, _destroy: "1" },
        "1" => { id: ingredients(:curry_roux).id, name: "カレールー", position: 1, _destroy: "0" }
      }
    } }
    assert_response :unprocessable_entity
    assert_select ".ingredient-row[hidden] input[name$='[_destroy]'][value='1']", 1
    assert_equal 2, ingredients(:curry_rice).recipe.ingredients.count # まだ消えていない
  end
end
