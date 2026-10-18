class Tag < ApplicationRecord
  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  normalizes :name, with: ->(n) { n.unicode_normalize(:nfkc).strip.downcase }

  validates :name, presence: true, uniqueness: true, length: { maximum: 20 }

  # 公開レシピでよく使われているタグ(使われている数の多い順)
  def self.popular(limit = 20)
    joins(:recipes).merge(Recipe.publicly_visible)
      .group(:id).select("tags.*, COUNT(recipes.id) AS recipes_count")
      .order("recipes_count DESC", :name).limit(limit)
  end
end
