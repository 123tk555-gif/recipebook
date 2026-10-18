class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :recipes, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { maximum: 30 }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
