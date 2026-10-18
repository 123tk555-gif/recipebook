require "test_helper"

class MealPlansControllerTest < ActionDispatch::IntegrationTest
  MONDAY = Date.new(2026, 10, 12)

  setup { @user = users(:one) }

  def plan!(user: @user, recipe: recipes(:public_one), date: MONDAY, slot: "dinner", **attrs)
    user.meal_plans.create!(recipe: recipe, date: date, slot: slot, **attrs)
  end

  test "ログインが必要" do
    get meal_plans_path
    assert_redirected_to new_session_path
  end

  test "週の表を表示する(月曜始まり、途中の日を指定しても同じ週)" do
    plan!(date: MONDAY + 2.days, slot: "lunch")
    sign_in_as(@user)
    get meal_plans_path(week: (MONDAY + 3.days).iso8601)
    assert_response :success
    assert_select "h1", /2026年10月12日.*2026年10月18日/
    assert_select "tbody tr", 7
    assert_select "td a", "太郎の公開カレー"
  end

  test "おかしな日付は今週にする" do
    sign_in_as(@user)
    get meal_plans_path(week: "not-a-date")
    assert_response :success
  end

  test "献立に追加・外すことができる" do
    sign_in_as(@user)
    assert_difference "MealPlan.count", 1 do
      post meal_plans_path, params: { meal_plan: { recipe_id: recipes(:public_two).id, date: MONDAY, slot: "breakfast", servings: 2 } }
    end
    plan = MealPlan.order(:id).last
    assert_redirected_to meal_plans_path(week: MONDAY)
    assert_equal [ @user, "breakfast", 2 ], [ plan.user, plan.slot, plan.servings ]

    assert_difference "MealPlan.count", -1 do
      delete meal_plan_path(plan)
    end
  end

  test "他人の非公開レシピは献立に入れられない" do
    sign_in_as(users(:two))
    assert_no_difference "MealPlan.count" do
      post meal_plans_path, params: { meal_plan: { recipe_id: recipes(:private_one).id, date: MONDAY, slot: "dinner" } }
    end
    assert_response :not_found
  end

  test "朝昼夜以外は入れられず、理由を出す" do
    sign_in_as(@user)
    assert_no_difference "MealPlan.count" do
      post meal_plans_path, params: { meal_plan: { recipe_id: recipes(:public_one).id, date: MONDAY, slot: "midnight" } }
    end
    follow_redirect!
    assert_select ".flash.alert"
  end

  test "他人の献立は見えず、外せない" do
    others = plan!(user: users(:two), recipe: recipes(:public_two))
    sign_in_as(@user)
    get meal_plans_path(week: MONDAY)
    assert_select "td a", text: "花子の公開サラダ", count: 0
    delete meal_plan_path(others)
    assert_response :not_found
  end

  test "見られなくなったレシピは名前を出さない" do
    plan!(user: users(:two), recipe: recipes(:public_one))
    recipes(:public_one).update!(published: false)
    sign_in_as(users(:two))
    get meal_plans_path(week: MONDAY)
    assert_select "td", /見られなくなったレシピ/
    assert_select "td a", text: "太郎の公開カレー", count: 0
  end

  test "その週の材料を、献立の人数に合わせて買い物リストに追加する" do
    plan!(date: MONDAY, servings: 2)               # 4人分のレシピを2人分
    plan!(date: MONDAY + 6.days)                   # 人数指定なし
    plan!(date: MONDAY + 7.days)                   # 次の週なので入らない
    sign_in_as(@user)

    assert_difference "ShoppingItem.count", 4 do
      post add_to_shopping_list_meal_plans_path(week: MONDAY)
    end
    assert_redirected_to shopping_items_path
    assert_equal [ "1合", "1/2箱", "2合", "1箱" ], @user.shopping_items.order(:id).pluck(:quantity)
  end

  test "見られなくなったレシピの材料は買い物リストに入れない" do
    plan!(user: users(:two), recipe: recipes(:public_one))
    recipes(:public_one).update!(published: false)
    sign_in_as(users(:two))
    assert_no_difference "ShoppingItem.count" do
      post add_to_shopping_list_meal_plans_path(week: MONDAY)
    end
  end

  test "詳細ページから献立に追加できる" do
    sign_in_as(users(:two))
    get recipe_path(recipes(:public_one))
    assert_select "form[action=?] input[name='meal_plan[recipe_id]'][value=?]", meal_plans_path, recipes(:public_one).id.to_s
  end
end
