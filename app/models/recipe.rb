class Recipe < ApplicationRecord
  TRASH_DAYS = 30
  MAX_TAGS = 10
  MAX_INGREDIENTS = 50
  MAX_STEPS = 50
  PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze
  PHOTO_MAX_BYTES = 5.megabytes

  # 作者が退会して、公開レシピを残したときは空になる
  belongs_to :user, optional: true
  has_many :ingredients, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :recipe
  has_many :steps, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :recipe
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags
  has_many :favorites, dependent: :destroy
  # 他の会員の献立に入っていても、レシピを完全に削除したら献立からも外す
  has_many :meal_plans, dependent: :delete_all
  # 買い物リストの項目は残す(どのレシピからかの記録だけを外す)
  has_many :shopping_items, dependent: :nullify
  has_many :reports, dependent: :destroy

  has_one_attached :photo do |attachable|
    attachable.variant :medium, resize_to_limit: [ 1200, 1200 ]
    attachable.variant :thumb, resize_to_fill: [ 400, 300 ]
  end

  accepts_nested_attributes_for :ingredients, allow_destroy: true,
                                reject_if: ->(attrs) { attrs["name"].blank? && attrs["quantity"].blank? }
  accepts_nested_attributes_for :steps, allow_destroy: true,
                                reject_if: ->(attrs) { attrs["body"].blank? }

  validates :user, presence: true, on: :create
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }
  validates :cooking_minutes, numericality: { only_integer: true, in: 1..1440 }, allow_nil: true
  validates :servings, numericality: { only_integer: true, in: 1..100 }, allow_nil: true
  validate :photo_is_acceptable
  validate :tag_count_is_within_limit
  validate :rows_are_within_limit

  after_save :purge_photo_if_requested

  scope :active, -> { where(deleted_at: nil) }
  scope :trashed, -> { where.not(deleted_at: nil) }
  # 誰でも見られるレシピ: ゴミ箱でなく、持ち主が公開にしていて、管理者が非公開にしていないもの
  scope :publicly_visible, -> { active.where(published: true, hidden_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # ゴミ箱に入れてから TRASH_DAYS 日を過ぎたレシピ
  scope :expired, -> { trashed.where(deleted_at: ...TRASH_DAYS.days.ago) }

  # 閲覧できるレシピ: 公開中のもの + 自分のもの(ゴミ箱は除く)
  def self.visible_to(user)
    return publicly_visible unless user

    publicly_visible.or(active.where(user_id: user.id))
  end

  def self.purge_expired
    expired.find_each(&:destroy!)
  end

  def trashed?
    deleted_at.present?
  end

  def trash!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def days_until_purge
    return unless trashed?

    [ ((deleted_at + TRASH_DAYS.days - Time.current) / 1.day).ceil, 0 ].max
  end

  def publicly_visible?
    !trashed? && published? && !hidden?
  end

  def owned_by?(user)
    user.present? && user_id.present? && user.id == user_id
  end

  # 見られる人: 誰でも(公開中のとき)・持ち主(非公開やゴミ箱でも)
  # 管理者は、これとは別に RecipesController#show で見られるようにしている
  def viewable_by?(user)
    publicly_visible? || owned_by?(user)
  end

  def editable_by?(user)
    owned_by?(user)
  end

  # 管理者による非公開
  def hidden?
    hidden_at.present?
  end

  def hide!
    update!(hidden_at: Time.current)
  end

  def unhide!
    update!(hidden_at: nil)
  end

  def author_name
    user&.display_name || "退会した会員"
  end

  # フォーム用: 写真の削除チェックボックス
  def remove_photo=(value)
    @remove_photo = ActiveModel::Type::Boolean.new.cast(value)
  end

  def remove_photo
    @remove_photo
  end

  # フォーム用: タグを「パスタ, 簡単」のような文字列で読み書きする
  def tag_list
    tags.map(&:name).join(", ")
  end

  def tag_list=(value)
    names = value.to_s.split(/[,、\s]+/).map { |n| Tag.normalize_value_for(:name, n) }.reject(&:blank?).uniq
    @tag_names_too_many = names.size > MAX_TAGS
    self.tags = names.first(MAX_TAGS).map { |n| Tag.find_or_initialize_by(name: n) }
  end

  private

  def purge_photo_if_requested
    return unless @remove_photo && photo.attached?
    # 新しい写真を同時に選んだときは、新しい方を残す
    return if attachment_changes["photo"].present?

    photo.purge_later
  end

  # 新しく選ばれた写真だけを確かめる(保存済みの写真は、登録時に確かめ済み)
  def photo_is_acceptable
    change = attachment_changes["photo"]
    return unless change && photo.attached?

    unless PHOTO_TYPES.include?(detect_photo_type(change.attachable))
      errors.add(:photo, "は JPEG・PNG・WebP のいずれかにしてください")
    end
    if photo.byte_size > PHOTO_MAX_BYTES
      errors.add(:photo, "は 5MB 以下にしてください")
    end
  end

  # ファイルの中身(先頭の数バイト)から種類を調べる。
  # Active Storage は、中身から分からないとき「送られてきた申告」をそのまま信じるため、
  # 画像でないファイルが「image/png」と名乗っても通ってしまう。それを防ぐ。
  def detect_photo_type(attachable)
    io = case attachable
    when Hash then attachable[:io]
    when ActionDispatch::Http::UploadedFile then attachable.tempfile
    end
    return unless io

    io.rewind
    Marcel::MimeType.for(io)
  ensure
    io&.rewind
  end

  def tag_count_is_within_limit
    errors.add(:tag_list, "は #{MAX_TAGS} 個までです") if @tag_names_too_many
  end

  # 材料・手順の数の上限(保存しない枠は数えない)。ボタンで枠を増やせるので、サーバー側でも確かめる
  def rows_are_within_limit
    kept = ->(rows) { rows.reject(&:marked_for_destruction?).size }
    errors.add(:ingredients, "は #{MAX_INGREDIENTS} 個までです") if kept.call(ingredients) > MAX_INGREDIENTS
    errors.add(:steps, "は #{MAX_STEPS} 個までです") if kept.call(steps) > MAX_STEPS
  end
end
