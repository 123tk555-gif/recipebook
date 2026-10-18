class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :recipes, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_recipes, through: :favorites, source: :recipe
  has_many :shopping_items, dependent: :delete_all
  has_many :meal_plans, dependent: :delete_all
  # 退会しても、通報の記録は残す(通報した人だけを空にする)
  has_many :reports, foreign_key: :reporter_id, inverse_of: :reporter, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { maximum: 30 }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def favorited?(recipe)
    favorites.exists?(recipe_id: recipe.id)
  end

  # 退会する。keep_public_recipes が true なら、公開中のレシピだけを
  # 作者「退会した会員」として残す(他の人のお気に入りや献立から突然消えないように)。
  # 非公開・ゴミ箱・管理者が非公開にしたレシピ、お気に入り、買い物リスト、献立、ログイン中の端末、
  # メールアドレスとパスワードは消す。
  def withdraw!(keep_public_recipes:)
    transaction do
      recipes.publicly_visible.update_all(user_id: nil, updated_at: Time.current) if keep_public_recipes
      destroy!
    end
  end

  # 管理者が1人もいなくならないようにするため
  def last_admin?
    admin? && !User.where(admin: true).where.not(id: id).exists?
  end

  # 利用停止。ログイン中の端末からもすぐに締め出す
  def suspend!
    transaction do
      update!(suspended: true)
      sessions.destroy_all
    end
  end

  def unsuspend!
    update!(suspended: false)
  end
end
