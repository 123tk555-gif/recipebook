# 公開レシピの検索・絞り込み・並び替え・ページ分け。
#   RecipeSearch.new(q: "トマト パスタ", tag: "簡単", max_minutes: 30, sort: "popular", page: 2)
class RecipeSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  PER_PAGE = 20
  MAX_WORDS = 5
  SORTS = {
    "new" => "新しい順",
    "popular" => "お気に入りが多い順",
    "quick" => "調理時間が短い順"
  }.freeze
  MINUTES = [ 15, 30, 60 ].freeze

  attribute :q, :string
  attribute :tag, :string
  attribute :max_minutes, :integer
  attribute :sort, :string
  attribute :page, :integer

  def sort
    SORTS.key?(super) ? super : "new"
  end

  def page
    [ super.to_i, 1 ].max
  end

  def max_minutes
    MINUTES.include?(super) ? super : nil
  end

  def tag
    super.presence && Tag.normalize_value_for(:name, super)
  end

  # キーワード(空白区切り。すべてを含むものに絞る)
  def words
    q.to_s.unicode_normalize(:nfkc).split(/[[:space:]]+/).reject(&:blank?).uniq.first(MAX_WORDS)
  end

  def filtered?
    words.any? || tag.present? || max_minutes.present?
  end

  def results
    @results ||= begin
      rows = ordered(scope).offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @next_page = rows.size > PER_PAGE
      rows.first(PER_PAGE)
    end
  end

  def next_page?
    results
    @next_page
  end

  def prev_page?
    page > 1
  end

  private

  def scope
    relation = Recipe.publicly_visible.includes(:user, :tags).with_attached_photo
    words.each { |word| relation = relation.where(id: ids_matching(word)) }
    relation = relation.where(id: RecipeTag.joins(:tag).where(tags: { name: tag }).select(:recipe_id)) if tag.present?
    relation = relation.where(cooking_minutes: ..max_minutes) if max_minutes
    relation
  end

  # 料理名・材料名・タグ名のどれかに語を含むレシピ
  def ids_matching(word)
    pattern = "%#{Recipe.sanitize_sql_like(word)}%"
    by_title = Recipe.where("recipes.title LIKE ?", pattern).select(:id)
    by_ingredient = Ingredient.where("ingredients.name LIKE ?", pattern).select(:recipe_id)
    by_tag = RecipeTag.joins(:tag).where("tags.name LIKE ?", Tag.normalize_value_for(:name, pattern)).select(:recipe_id)

    Recipe.where(id: by_title).or(Recipe.where(id: by_ingredient)).or(Recipe.where(id: by_tag)).select(:id)
  end

  def ordered(relation)
    case sort
    when "popular" then relation.order(favorites_count: :desc, created_at: :desc, id: :desc)
    when "quick" then relation.order(Arel.sql("recipes.cooking_minutes IS NULL"), cooking_minutes: :asc, id: :desc)
    else relation.newest_first
    end
  end
end
