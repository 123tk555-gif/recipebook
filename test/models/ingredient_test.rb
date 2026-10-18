require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  test "材料名は必須で50文字まで、分量は30文字まで" do
    recipe = recipes(:public_one)
    assert_not recipe.ingredients.new(name: "").valid?
    assert_not recipe.ingredients.new(name: "あ" * 51).valid?
    assert_not recipe.ingredients.new(name: "塩", quantity: "あ" * 31).valid?
    assert recipe.ingredients.new(name: "塩", quantity: "少々").valid?
  end
end
