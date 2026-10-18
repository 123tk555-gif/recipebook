require "test_helper"

class OgpAndShareTest < ActionDispatch::IntegrationTest
  test "公開レシピには OGP が付く(写真なし)" do
    get recipe_path(recipes(:public_one))
    assert_select "meta[property='og:title'][content=?]", "太郎の公開カレー"
    assert_select "meta[property='og:type'][content=?]", "article"
    assert_select "meta[property='og:url'][content=?]", recipe_url(recipes(:public_one))
    assert_select "meta[property='og:description'][content=?]", "辛口です"
    assert_select "meta[name='twitter:card'][content=?]", "summary"
    assert_select "meta[property='og:image']", 0
  end

  test "写真があれば og:image を絶対URLで付ける" do
    recipe = recipes(:public_one)
    recipe.photo.attach(io: File.open(file_fixture("pixel.png")), filename: "pixel.png", content_type: "image/png")
    get recipe_path(recipe)
    assert_select "meta[property='og:image']" do |tags|
      assert_match %r{\Ahttp://www.example.com/rails/active_storage/}, tags.first["content"]
    end
    assert_select "meta[name='twitter:card'][content=?]", "summary_large_image"
  end

  test "説明がないときは、材料と手順の数から説明を作る" do
    get recipe_path(recipes(:public_two))
    assert_select "meta[property='og:description'][content=?]", "花子の公開サラダのレシピ。材料0品、0ステップ。"
  end

  test "非公開・管理者が非公開にしたレシピには、持ち主が見ても OGP と共有ボタンを付けない" do
    sign_in_as(users(:one))
    get recipe_path(recipes(:private_one))
    assert_select "meta[property='og:type'][content=?]", "website"
    assert_select ".share", 0

    recipes(:public_one).hide!
    get recipe_path(recipes(:public_one))
    assert_select "meta[property='og:type'][content=?]", "website"
    assert_select ".share", 0
  end

  test "ほかのページにはサイトの OGP を付ける" do
    get root_path
    assert_select "meta[property='og:site_name'][content=?]", "レシピ管理"
    assert_select "meta[property='og:type'][content=?]", "website"
  end

  test "公開レシピには共有の欄(URL・X・LINE)がある" do
    recipe = recipes(:public_one)
    get recipe_path(recipe)
    assert_select ".share input#share-url[value=?][readonly]", recipe_url(recipe)
    assert_select ".share button", "URL をコピー"
    assert_select ".share a[href^='https://x.com/intent/post?'][target=_blank][rel~=noopener]"
    assert_select ".share a[href^='https://social-plugins.line.me/lineit/share?']"
  end
end
