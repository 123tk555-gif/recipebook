class Step < ApplicationRecord
  belongs_to :recipe

  validates :body, presence: true, length: { maximum: 1000 }
end
