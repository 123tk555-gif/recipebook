class Ingredient < ApplicationRecord
  belongs_to :recipe

  validates :name, presence: true, length: { maximum: 50 }
  validates :quantity, length: { maximum: 30 }
end
