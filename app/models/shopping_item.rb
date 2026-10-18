class ShoppingItem < ApplicationRecord
  MAX_PER_USER = 500

  belongs_to :user
  belongs_to :recipe, optional: true

  validates :name, presence: true, length: { maximum: 50 }
  validates :quantity, length: { maximum: 50 }
  validate :within_limit, on: :create

  scope :in_display_order, -> { order(:checked, :created_at, :id) }

  # レシピの材料をまとめて追加する。servings を指定すると、分量をその人数分に計算し直す
  # (レシピに人数が書かれていないときは計算できないので、そのままの分量にする)
  def self.add_from_recipe!(user:, recipe:, servings: nil)
    count = servings.to_i
    ratio = count.between?(1, 100) && recipe.servings.present? ? Rational(count, recipe.servings) : 1
    transaction do
      recipe.ingredients.map do |ingredient|
        user.shopping_items.create!(
          recipe: recipe,
          name: ingredient.name,
          quantity: QuantityScaler.scale(ingredient.quantity, ratio)
        )
      end
    end
  end

  private

  def within_limit
    return unless user && user.shopping_items.count >= MAX_PER_USER

    errors.add(:base, "買い物リストは#{MAX_PER_USER}件までです。買ったものを消してから追加してください")
  end
end
