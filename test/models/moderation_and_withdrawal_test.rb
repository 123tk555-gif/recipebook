require "test_helper"

# 管理者による非公開・利用停止・退会のモデル側の動き
class ModerationAndWithdrawalTest < ActiveSupport::TestCase
  test "管理者が非公開にしたレシピは、どこにも公開されない" do
    recipe = recipes(:public_one)
    recipe.hide!
    assert recipe.hidden?
    assert_not recipe.publicly_visible?
    assert_not_includes Recipe.publicly_visible, recipe
    assert_not_includes Recipe.visible_to(nil), recipe
    assert_not_includes Recipe.visible_to(users(:two)), recipe
    assert_not_includes RecipeSearch.new.results, recipe
  end

  test "管理者が非公開にしても、持ち主は見られる" do
    recipe = recipes(:public_one)
    recipe.hide!
    assert recipe.viewable_by?(users(:one))
    assert_includes Recipe.visible_to(users(:one)), recipe
    assert_not recipe.viewable_by?(users(:two))
  end

  test "非公開を解除すると元に戻る" do
    recipe = recipes(:public_one)
    recipe.hide!
    recipe.unhide!
    assert recipe.publicly_visible?
  end

  test "非公開にしたレシピのタグは、よく使われるタグに出ない" do
    recipe = users(:two).recipes.create!(title: "隠す", published: true, tag_list: "ひみつ")
    assert_includes Tag.popular.map(&:name), "ひみつ"
    recipe.hide!
    assert_not_includes Tag.popular.map(&:name), "ひみつ"
  end

  test "利用停止にすると、ログイン中の端末も締め出す" do
    user = users(:two)
    user.sessions.create!
    user.suspend!
    assert user.suspended?
    assert_empty user.sessions.reload
    user.unsuspend!
    assert_not user.suspended?
  end

  test "退会(公開レシピを残す): 公開中のものだけ作者なしで残り、ほかは消える" do
    user = users(:one)
    users(:two).favorites.create!(recipe: recipes(:public_one))
    users(:two).meal_plans.create!(recipe: recipes(:public_one), date: Date.current, slot: "dinner")
    user.favorites.create!(recipe: recipes(:public_two))
    user.shopping_items.create!(name: "牛乳")
    public_id, private_id, trashed_id = recipes(:public_one).id, recipes(:private_one).id, recipes(:trashed_one).id

    user.withdraw!(keep_public_recipes: true)

    assert_not User.exists?(user.id)
    kept = Recipe.find(public_id)
    assert_nil kept.user
    assert_equal "退会した会員", kept.author_name
    assert kept.publicly_visible?
    assert_not Recipe.exists?(private_id)
    assert_not Recipe.exists?(trashed_id)
    assert_equal 1, kept.favorites.count
    assert_equal 1, kept.meal_plans.count
    assert_equal 0, ShoppingItem.where(user_id: user.id).count
    assert_equal 0, Favorite.where(user_id: user.id).count
  end

  test "退会(すべて削除): レシピも全部消え、他の人のお気に入りや献立からも外れる" do
    users(:two).favorites.create!(recipe: recipes(:public_one))
    users(:two).meal_plans.create!(recipe: recipes(:public_one), date: Date.current, slot: "dinner")
    ids = [ recipes(:public_one).id, recipes(:private_one).id ]

    users(:one).withdraw!(keep_public_recipes: false)

    assert_equal 0, Recipe.where(id: ids).count
    assert_equal 0, users(:two).favorites.count
    assert_equal 0, users(:two).meal_plans.count
  end

  test "管理者が非公開にしたレシピは、退会時に残さない" do
    recipes(:public_one).hide!
    users(:one).withdraw!(keep_public_recipes: true)
    assert_not Recipe.exists?(recipes(:public_one).id)
  end

  test "作者のいないレシピは、誰も編集できない" do
    recipe = recipes(:public_one)
    recipe.update_columns(user_id: nil)
    assert_not recipe.reload.editable_by?(users(:one))
    assert_not recipe.editable_by?(nil)
    assert recipe.viewable_by?(nil)
  end

  test "新しいレシピには作者が必要" do
    assert_not Recipe.new(title: "作者なし").valid?
  end

  test "last_admin?" do
    assert users(:admin).last_admin?
    assert_not users(:one).last_admin?
    users(:one).update!(admin: true)
    assert_not users(:admin).last_admin?
  end
end
