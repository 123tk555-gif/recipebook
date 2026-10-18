class MealPlan < ApplicationRecord
  MAX_PER_DAY = 20

  belongs_to :user
  belongs_to :recipe

  enum :slot, { breakfast: 0, lunch: 1, dinner: 2 }, validate: true
  SLOT_NAMES = { "breakfast" => "朝", "lunch" => "昼", "dinner" => "夜" }.freeze

  validates :date, presence: true
  validates :servings, numericality: { only_integer: true, in: 1..100 }, allow_nil: true
  validate :recipe_is_visible_to_user
  validate :within_daily_limit, on: :create

  scope :in_week, ->(start) { where(date: start..(start + 6.days)) }

  def slot_name
    SLOT_NAMES.fetch(slot)
  end

  private

  # 自分のレシピか、公開中のレシピだけを献立に入れられる
  def recipe_is_visible_to_user
    return unless recipe && user

    errors.add(:recipe, "は献立に追加できません") unless recipe.viewable_by?(user) && !recipe.trashed?
  end

  def within_daily_limit
    return unless user && date && user.meal_plans.where(date: date).count >= MAX_PER_DAY

    errors.add(:base, "1日の献立は#{MAX_PER_DAY}件までです")
  end
end
