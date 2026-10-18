require "test_helper"

class MealPlanTest < ActiveSupport::TestCase
  def build(overrides = {})
    users(:one).meal_plans.new({ recipe: recipes(:public_one), date: Date.current, slot: "dinner" }.merge(overrides))
  end

  test "自分のレシピと公開レシピは献立に入れられる" do
    assert build.valid?
    assert build(recipe: recipes(:private_one)).valid?
    assert build(recipe: recipes(:public_two)).valid?
  end

  test "他人の非公開レシピ・ゴミ箱のレシピは入れられない" do
    assert_not users(:two).meal_plans.new(recipe: recipes(:private_one), date: Date.current, slot: "lunch").valid?
    assert_not build(recipe: recipes(:trashed_one)).valid?
  end

  test "朝・昼・夜以外は入れられない" do
    assert_not build(slot: "midnight").valid?
  end

  test "日付は必須、人数は1〜100" do
    assert_not build(date: nil).valid?
    assert_not build(servings: 0).valid?
    assert build(servings: 3).valid?
  end

  test "1日20件まで" do
    MealPlan::MAX_PER_DAY.times { build.save! }
    assert_not build.valid?
  end

  test "in_week は7日分" do
    monday = Date.new(2026, 10, 12)
    inside = build(date: monday + 6.days).tap(&:save!)
    outside = build(date: monday + 7.days).tap(&:save!)
    assert_includes MealPlan.in_week(monday), inside
    assert_not_includes MealPlan.in_week(monday), outside
  end

  test "レシピを完全に削除すると、他の人の献立からも外れる" do
    users(:two).meal_plans.create!(recipe: recipes(:public_one), date: Date.current, slot: "lunch")
    assert_difference "MealPlan.count", -1 do
      recipes(:public_one).destroy!
    end
  end
end
