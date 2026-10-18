class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_recipes, through: :favorites, source: :recipe
  has_many :shopping_items, dependent: :delete_all
  has_many :meal_plans, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { maximum: 30 }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def favorited?(recipe)
    favorites.exists?(recipe_id: recipe.id)
  end
end
