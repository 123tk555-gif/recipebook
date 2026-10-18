require "test_helper"

class ShoppingItemTest < ActiveSupport::TestCase
  test "品名は必須で50文字まで" do
    assert_not users(:one).shopping_items.new(name: "").valid?
    assert_not users(:one).shopping_items.new(name: "あ" * 51).valid?
    assert users(:one).shopping_items.new(name: "牛乳", quantity: "1本").valid?
  end

  test "未購入が先、買ったものが後に並ぶ" do
    done = users(:one).shopping_items.create!(name: "買った", checked: true)
    todo = users(:one).shopping_items.create!(name: "まだ")
    assert_equal [ todo, done ], users(:one).shopping_items.in_display_order.to_a
  end

  test "1人500件まで" do
    rows = Array.new(ShoppingItem::MAX_PER_USER) { |i| { user_id: users(:one).id, name: "品#{i}", created_at: Time.current, updated_at: Time.current } }
    ShoppingItem.insert_all!(rows)
    item = users(:one).shopping_items.new(name: "はみ出し")
    assert_not item.valid?
    assert_match "500件まで", item.errors.full_messages.to_sentence
  end

  test "レシピの材料を人数に合わせて追加する(4人分 → 2人分)" do
    items = ShoppingItem.add_from_recipe!(user: users(:two), recipe: recipes(:public_one), servings: 2)
    assert_equal [ [ "米", "1合" ], [ "カレールー", "1/2箱" ] ], items.map { |i| [ i.name, i.quantity ] }
    assert items.all? { |i| i.recipe == recipes(:public_one) }
  end

  test "人数を指定しないと分量はそのまま" do
    items = ShoppingItem.add_from_recipe!(user: users(:two), recipe: recipes(:public_one))
    assert_equal [ "2合", "1箱" ], items.map(&:quantity)
  end

  test "レシピに人数がないと計算できないので、分量はそのまま" do
    recipe = recipes(:public_two)
    recipe.ingredients.create!(name: "レタス", quantity: "1/2玉")
    items = ShoppingItem.add_from_recipe!(user: users(:one), recipe: recipe, servings: 4)
    assert_equal [ "1/2玉" ], items.map(&:quantity)
  end

  test "ありえない人数は無視する" do
    items = ShoppingItem.add_from_recipe!(user: users(:two), recipe: recipes(:public_one), servings: 0)
    assert_equal [ "2合", "1箱" ], items.map(&:quantity)
  end

  test "レシピを完全に削除しても、買い物リストの項目は残る" do
    items = ShoppingItem.add_from_recipe!(user: users(:two), recipe: recipes(:public_one))
    recipes(:public_one).destroy!
    assert_nil items.first.reload.recipe_id
  end
end
