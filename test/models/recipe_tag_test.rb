require "test_helper"

class RecipeTagTest < ActiveSupport::TestCase
  test "同じレシピに同じタグは2回付けられない" do
    tag = Tag.create!(name: "和食")
    RecipeTag.create!(recipe: recipes(:public_one), tag: tag)
    assert_not RecipeTag.new(recipe: recipes(:public_one), tag: tag).valid?
  end
end
