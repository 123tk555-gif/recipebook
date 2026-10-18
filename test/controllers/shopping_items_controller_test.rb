require "test_helper"

class ShoppingItemsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "ログインが必要" do
    get shopping_items_path
    assert_redirected_to new_session_path
    post recipe_shopping_items_path(recipes(:public_one))
    assert_redirected_to new_session_path
  end

  test "手で追加・一覧表示できる" do
    sign_in_as(@user)
    post shopping_items_path, params: { shopping_item: { name: "牛乳", quantity: "1本" } }
    assert_redirected_to shopping_items_path
    follow_redirect!
    assert_select ".shopping-list li", /\[未購入\]\s*牛乳\s*1本/
  end

  test "品名が空だと追加できない" do
    sign_in_as(@user)
    assert_no_difference "ShoppingItem.count" do
      post shopping_items_path, params: { shopping_item: { name: "" } }
    end
    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "買ったチェックを付け外しできる(文字でも表示)" do
    item = @user.shopping_items.create!(name: "卵")
    sign_in_as(@user)

    patch shopping_item_path(item, checked: true)
    assert item.reload.checked?
    follow_redirect!
    assert_select ".shopping-list li.checked", /\[買った\]\s*卵/

    patch shopping_item_path(item, checked: false)
    assert_not item.reload.checked?
  end

  test "1件・買ったもの・すべてを消せる" do
    a = @user.shopping_items.create!(name: "A")
    @user.shopping_items.create!(name: "B", checked: true)
    @user.shopping_items.create!(name: "C")
    sign_in_as(@user)

    delete shopping_item_path(a)
    assert_equal %w[B C], @user.shopping_items.order(:name).pluck(:name)

    delete clear_checked_shopping_items_path
    assert_equal %w[C], @user.shopping_items.pluck(:name)

    delete clear_all_shopping_items_path
    assert_equal 0, ShoppingItem.where(user: @user).count
  end

  test "他人の買い物リストは見えず、操作もできない" do
    others = users(:two).shopping_items.create!(name: "ひみつの品")
    sign_in_as(@user)

    get shopping_items_path
    assert_select "li", text: /ひみつの品/, count: 0

    patch shopping_item_path(others, checked: true)
    assert_response :not_found
    delete shopping_item_path(others)
    assert_response :not_found

    delete clear_all_shopping_items_path
    assert ShoppingItem.exists?(others.id)
  end

  test "レシピの材料を人数を指定して追加できる" do
    sign_in_as(users(:two))
    assert_difference "ShoppingItem.count", 2 do
      post recipe_shopping_items_path(recipes(:public_one)), params: { servings: 8 }
    end
    assert_redirected_to shopping_items_path
    assert_equal [ "4合", "2箱" ], users(:two).shopping_items.order(:id).pluck(:quantity)
  end

  test "他人の非公開レシピの材料は追加できない" do
    sign_in_as(users(:two))
    assert_no_difference "ShoppingItem.count" do
      post recipe_shopping_items_path(recipes(:private_one))
    end
    assert_response :not_found
  end

  test "上限を超えると追加せずに理由を出す" do
    rows = Array.new(ShoppingItem::MAX_PER_USER - 1) { |i| { user_id: users(:two).id, name: "品#{i}", created_at: Time.current, updated_at: Time.current } }
    ShoppingItem.insert_all!(rows)
    sign_in_as(users(:two))
    assert_no_difference "ShoppingItem.count" do
      post recipe_shopping_items_path(recipes(:public_one))
    end
    assert_redirected_to recipe_path(recipes(:public_one))
    follow_redirect!
    assert_select ".flash.alert", /500件まで/
  end

  test "詳細ページに追加フォームが出る(ログイン時のみ)" do
    get recipe_path(recipes(:public_one))
    assert_select "form[action=?]", recipe_shopping_items_path(recipes(:public_one)), count: 0

    sign_in_as(users(:two))
    get recipe_path(recipes(:public_one))
    assert_select "form[action=?]", recipe_shopping_items_path(recipes(:public_one))
    assert_select "input[name=servings][value='4']"
  end
end
