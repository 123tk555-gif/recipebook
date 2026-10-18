require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  def build(overrides = {})
    users(:one).recipes.new({ title: "新しいレシピ" }.merge(overrides))
  end

  test "料理名は必須で100文字まで" do
    assert_not build(title: "").valid?
    assert_not build(title: "あ" * 101).valid?
    assert build(title: "あ" * 100).valid?
  end

  test "調理時間と人数は範囲内の整数" do
    assert_not build(cooking_minutes: 0).valid?
    assert_not build(cooking_minutes: 1441).valid?
    assert_not build(servings: 0).valid?
    assert_not build(servings: 101).valid?
    assert_not build(servings: 1.5).valid?
    assert build(cooking_minutes: 15, servings: 2).valid?
  end

  test "非公開が既定" do
    assert_not Recipe.new.published?
  end

  test "visible_to: ログインなしは公開中のものだけ" do
    titles = Recipe.visible_to(nil).pluck(:title)
    assert_includes titles, "太郎の公開カレー"
    assert_includes titles, "花子の公開サラダ"
    assert_not_includes titles, "太郎の非公開レシピ"
    assert_not_includes titles, "太郎のゴミ箱レシピ"
  end

  test "visible_to: 会員は公開中 + 自分のレシピ(ゴミ箱は除く)" do
    titles = Recipe.visible_to(users(:one)).pluck(:title)
    assert_includes titles, "太郎の非公開レシピ"
    assert_includes titles, "花子の公開サラダ"
    assert_not_includes titles, "太郎のゴミ箱レシピ"
    assert_not_includes Recipe.visible_to(users(:two)).pluck(:title), "太郎の非公開レシピ"
  end

  test "viewable_by? と editable_by?" do
    private_recipe = recipes(:private_one)
    assert private_recipe.viewable_by?(users(:one))
    assert_not private_recipe.viewable_by?(users(:two))
    assert_not private_recipe.viewable_by?(nil)
    assert recipes(:public_one).viewable_by?(nil)
    assert recipes(:public_one).editable_by?(users(:one))
    assert_not recipes(:public_one).editable_by?(users(:two))
    assert_not recipes(:public_one).editable_by?(nil)
  end

  test "ゴミ箱のレシピは持ち主だけが見られる" do
    assert recipes(:trashed_one).viewable_by?(users(:one))
    assert_not recipes(:trashed_one).viewable_by?(users(:two))
    assert_not recipes(:trashed_one).viewable_by?(nil)
  end

  test "trash! と restore!" do
    recipe = recipes(:public_one)
    recipe.trash!
    assert recipe.trashed?
    assert_not_includes Recipe.active, recipe
    recipe.restore!
    assert_not recipe.trashed?
  end

  test "days_until_purge" do
    assert_nil recipes(:public_one).days_until_purge
    assert_equal 27, recipes(:trashed_one).days_until_purge
  end

  test "purge_expired は30日たったものだけ完全に削除する" do
    expired_id = recipes(:expired_one).id
    kept_id = recipes(:trashed_one).id
    assert_difference "Recipe.count", -1 do
      Recipe.purge_expired
    end
    assert_not Recipe.exists?(expired_id)
    assert Recipe.exists?(kept_id)
  end

  test "レシピを消すと材料と手順も消える" do
    recipe = recipes(:public_one)
    assert_difference [ "Ingredient.count", "Step.count" ], -2 do
      recipe.destroy!
    end
  end

  test "材料と手順の空の行は無視される" do
    recipe = build(
      ingredients_attributes: [ { name: "塩", quantity: "少々" }, { name: "", quantity: "" } ],
      steps_attributes: [ { body: "混ぜる" }, { body: "" } ]
    )
    assert recipe.save
    assert_equal 1, recipe.ingredients.size
    assert_equal 1, recipe.steps.size
  end

  test "tag_list を読み書きできる" do
    recipe = build(tag_list: "パスタ、 簡単  パスタ")
    assert recipe.save
    assert_equal [ "パスタ", "簡単" ], recipe.reload.tags.map(&:name).sort
  end

  test "タグは全角・大文字を整えて、既存のタグを使い回す" do
    existing = Tag.create!(name: "easy")
    recipe = build(tag_list: "ＥＡＳＹ")
    assert_no_difference "Tag.count" do
      recipe.save!
    end
    assert_equal [ existing ], recipe.tags.to_a
  end

  test "タグは10個まで" do
    assert_not build(tag_list: (1..11).map { |i| "タグ#{i}" }.join(",")).valid?
    assert build(tag_list: (1..10).map { |i| "タグ#{i}" }.join(",")).valid?
  end

  test "タグは20文字まで" do
    assert_not build(tag_list: "あ" * 21).valid?
  end

  PNG_MAGIC = "\x89PNG\r\n\x1a\n".b

  test "写真: 正しい画像は受け付ける" do
    recipe = build
    recipe.photo.attach(io: File.open(file_fixture("pixel.png")), filename: "pixel.png", content_type: "image/png")
    assert recipe.valid?, recipe.errors.full_messages.to_sentence
  end

  test "写真: JPEG・PNG・WebP 以外の画像は受け付けない" do
    recipe = build
    recipe.photo.attach(io: StringIO.new("GIF89a"), filename: "a.gif", content_type: "image/gif")
    assert_not recipe.valid?
    assert_match "JPEG", recipe.errors[:photo].to_sentence
  end

  test "写真: 画像でないファイルは、画像と名乗っても受け付けない" do
    recipe = build
    recipe.photo.attach(io: StringIO.new("<html><script>alert(1)</script></html>"), filename: "evil.png", content_type: "image/png")
    assert_not recipe.valid?
    assert_match "JPEG", recipe.errors[:photo].to_sentence
  end

  test "写真: 5MBを超えると受け付けない" do
    big = build
    big.photo.attach(io: StringIO.new(PNG_MAGIC + ("x" * (5.megabytes + 1))), filename: "big.png", content_type: "image/png")
    assert_not big.valid?
    assert_match "5MB", big.errors[:photo].to_sentence
  end

  test "写真: 5MB ちょうどまでは受け付ける" do
    ok = build
    ok.photo.attach(io: StringIO.new(PNG_MAGIC + ("x" * (5.megabytes - PNG_MAGIC.bytesize))), filename: "ok.png", content_type: "image/png")
    assert ok.valid?, ok.errors.full_messages.to_sentence
  end
end
