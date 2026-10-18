class Report < ApplicationRecord
  REASONS = {
    "spam" => "宣伝・スパム",
    "inappropriate" => "不適切な内容(暴力・差別・わいせつなど)",
    "copyright" => "他の人の文章や写真の無断転載",
    "dangerous" => "健康や安全に関わる誤り",
    "other" => "その他"
  }.freeze
  STATUSES = { "open" => "未対応", "hidden" => "非公開にした", "dismissed" => "問題なし" }.freeze

  belongs_to :recipe
  belongs_to :reporter, class_name: "User", optional: true
  belongs_to :handled_by, class_name: "User", optional: true

  enum :reason, { spam: 0, inappropriate: 1, copyright: 2, dangerous: 3, other: 4 }, validate: true
  enum :status, { open: 0, hidden: 1, dismissed: 2 }, prefix: true

  validates :detail, length: { maximum: 500 }
  validates :reporter, presence: true, on: :create
  validate :reportable, on: :create

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def reason_name = REASONS.fetch(reason)
  def status_name = STATUSES.fetch(status)

  private

  def reportable
    return unless recipe && reporter

    if recipe.user_id == reporter.id
      errors.add(:base, "自分のレシピは通報できません")
    elsif !recipe.publicly_visible?
      errors.add(:base, "このレシピは通報できません")
    elsif Report.status_open.exists?(recipe: recipe, reporter: reporter)
      errors.add(:base, "このレシピはすでに通報済みです。管理者の確認をお待ちください")
    end
  end
end
