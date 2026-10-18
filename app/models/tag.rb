class Tag < ApplicationRecord
  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  normalizes :name, with: ->(n) { n.unicode_normalize(:nfkc).strip.downcase }

  validates :name, presence: true, uniqueness: true, length: { maximum: 20 }
end
