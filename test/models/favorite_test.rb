require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "同じレシピを2回お気に入りにできない" do
    Favorite.create!(user: users(:one), recipe: recipes(:public_two))
    assert_not Favorite.new(user: users(:one), recipe: recipes(:public_two)).valid?
  end

  test "件数がレシピ側に数えられる" do
    recipe = recipes(:public_two)
    Favorite.create!(user: users(:one), recipe: recipe)
    Favorite.create!(user: users(:two), recipe: recipe)
    assert_equal 2, recipe.reload.favorites_count
  end
end
