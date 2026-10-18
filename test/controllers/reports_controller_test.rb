require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "ログインが必要" do
    get new_recipe_report_path(recipes(:public_one))
    assert_redirected_to new_session_path
  end

  test "通報フォームから通報できる" do
    sign_in_as(users(:two))
    get new_recipe_report_path(recipes(:public_one))
    assert_response :success
    assert_select "input[type=radio][name='report[reason]']", Report::REASONS.size

    assert_difference "Report.count", 1 do
      post recipe_reports_path(recipes(:public_one)), params: { report: { reason: "copyright", detail: "雑誌の文章と同じです" } }
    end
    assert_redirected_to recipe_path(recipes(:public_one))
    report = Report.last
    assert_equal [ users(:two), "copyright", "open" ], [ report.reporter, report.reason, report.status ]
  end

  test "理由がないと通報できない" do
    sign_in_as(users(:two))
    assert_no_difference "Report.count" do
      post recipe_reports_path(recipes(:public_one)), params: { report: { reason: "", detail: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "自分のレシピは通報できない(フォームにも理由を出す)" do
    sign_in_as(users(:one))
    assert_no_difference "Report.count" do
      post recipe_reports_path(recipes(:public_one)), params: { report: { reason: "spam" } }
    end
    assert_select ".errors", /自分のレシピ/
  end

  test "非公開のレシピは通報の画面も出さない(404)" do
    sign_in_as(users(:two))
    get new_recipe_report_path(recipes(:private_one))
    assert_response :not_found
  end

  test "詳細ページの通報リンクは、ログイン中で自分以外の公開レシピだけ" do
    get recipe_path(recipes(:public_one))
    assert_select "a.report-link", count: 0

    sign_in_as(users(:one))
    get recipe_path(recipes(:public_one))
    assert_select "a.report-link", count: 0

    sign_in_as(users(:two))
    get recipe_path(recipes(:public_one))
    assert_select "a.report-link", "このレシピを通報する"
  end
end
