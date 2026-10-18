require "test_helper"

class ReportTest < ActiveSupport::TestCase
  def build(overrides = {})
    Report.new({ recipe: recipes(:public_one), reporter: users(:two), reason: "spam" }.merge(overrides))
  end

  test "公開レシピを通報できる" do
    assert build.save
    assert build(reporter: users(:admin)).valid?
  end

  test "理由は決められたものだけ、補足は500文字まで" do
    assert_not build(reason: "nonsense").valid?
    assert_not build(detail: "あ" * 501).valid?
  end

  test "自分のレシピは通報できない" do
    report = build(reporter: users(:one))
    assert_not report.valid?
    assert_match "自分のレシピ", report.errors.full_messages.to_sentence
  end

  test "非公開・ゴミ箱・管理者が非公開にしたレシピは通報できない" do
    assert_not build(recipe: recipes(:private_one)).valid?
    assert_not build(recipe: recipes(:trashed_one)).valid?
    recipes(:public_two).hide!
    assert_not build(recipe: recipes(:public_two), reporter: users(:one)).valid?
  end

  test "未対応の通報があるうちは、同じ人が同じレシピを重ねて通報できない" do
    build.save!
    assert_not build.valid?
    Report.update_all(status: Report.statuses["dismissed"])
    assert build.valid?
  end

  test "通報した人が退会しても通報は残る" do
    report = build.tap(&:save!)
    users(:two).withdraw!(keep_public_recipes: false)
    assert_nil report.reload.reporter
  end

  test "レシピを完全に削除すると通報も消える" do
    build.save!
    assert_difference "Report.count", -1 do
      recipes(:public_one).destroy!
    end
  end
end
