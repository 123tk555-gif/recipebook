require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  def report!(recipe: recipes(:public_one), reporter: users(:two), reason: "spam")
    Report.create!(recipe: recipe, reporter: reporter, reason: reason)
  end

  # --- 管理者以外 ---
  test "管理者以外には管理画面があること自体を見せない" do
    get admin_reports_path
    assert_redirected_to new_session_path

    sign_in_as(users(:one))
    get admin_reports_path
    assert_response :not_found
    get admin_users_path
    assert_response :not_found
    post hide_admin_recipe_path(recipes(:public_two))
    assert_response :not_found
    post suspend_admin_user_path(users(:two))
    assert_response :not_found
    assert_not recipes(:public_two).reload.hidden?
    assert_not users(:two).reload.suspended?
  end

  test "管理者以外にはメニューに管理画面が出ない" do
    sign_in_as(users(:one))
    get root_path
    assert_select "a", text: "管理画面", count: 0
    sign_in_as(users(:admin))
    get root_path
    assert_select "a", "管理画面"
  end

  # --- 通報 ---
  test "未対応の通報が一覧に出る" do
    report!(reason: "copyright")
    sign_in_as(users(:admin))
    get admin_reports_path
    assert_response :success
    assert_select ".report", /太郎の公開カレー/
    assert_select ".report", /他の人の文章や写真の無断転載/
    assert_select "a", /未対応\(1件\)/
  end

  test "「非公開にする」で、レシピが非公開になり、同じレシピの未対応の通報もまとめて対応済みになる" do
    first = report!
    second = report!(reporter: users(:admin))
    other = report!(recipe: recipes(:public_two), reporter: users(:one))
    sign_in_as(users(:admin))

    patch admin_report_path(first, decision: "hidden")
    assert_redirected_to admin_reports_path
    assert recipes(:public_one).reload.hidden?
    assert [ first, second ].all? { |r| r.reload.status_hidden? && r.handled_by == users(:admin) && r.handled_at }
    assert other.reload.status_open?
  end

  test "「問題なし」にすると、レシピはそのまま" do
    report = report!
    sign_in_as(users(:admin))
    patch admin_report_path(report, decision: "dismissed")
    assert report.reload.status_dismissed?
    assert_not recipes(:public_one).reload.hidden?
  end

  test "おかしな対応の種類は受け付けない" do
    report = report!
    sign_in_as(users(:admin))
    patch admin_report_path(report, decision: "delete_everything")
    assert report.reload.status_open?
  end

  # --- レシピ ---
  test "管理者は非公開のレシピも見られ、非公開にしたり解除したりできる" do
    sign_in_as(users(:admin))
    get recipe_path(recipes(:private_one))
    assert_response :success

    post hide_admin_recipe_path(recipes(:public_two))
    assert recipes(:public_two).reload.hidden?
    get recipe_path(recipes(:public_two))
    assert_select ".flash.alert", /管理者が非公開/
    post unhide_admin_recipe_path(recipes(:public_two))
    assert_not recipes(:public_two).reload.hidden?
  end

  test "管理者が非公開にしたレシピは、他の人には404、持ち主には注意を出す" do
    recipes(:public_one).hide!
    get recipe_path(recipes(:public_one))
    assert_response :not_found

    sign_in_as(users(:one))
    get recipe_path(recipes(:public_one))
    assert_response :success
    assert_select ".flash.alert", /管理者が非公開/
    assert_select ".badge", "非公開"
  end

  # --- 会員 ---
  test "会員を探して、利用停止・解除ができる" do
    sign_in_as(users(:admin))
    get admin_users_path(q: "花子")
    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody th", "花子"

    users(:two).sessions.create!
    post suspend_admin_user_path(users(:two))
    assert users(:two).reload.suspended?
    assert_empty users(:two).sessions

    post unsuspend_admin_user_path(users(:two))
    assert_not users(:two).reload.suspended?
  end

  test "管理者は利用停止にできない" do
    users(:one).update!(admin: true)
    sign_in_as(users(:admin))
    post suspend_admin_user_path(users(:one))
    assert_not users(:one).reload.suspended?
  end

  test "検索の % はそのままの文字として探す" do
    sign_in_as(users(:admin))
    get admin_users_path(q: "%")
    assert_select "tbody tr", 0
  end
end
