class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :recipe, counter_cache: true

  validates :recipe_id, uniqueness: { scope: :user_id }
end
