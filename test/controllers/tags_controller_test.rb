require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "公開レシピのタグだけを、使われている数とともに出す" do
    users(:two).recipes.create!(title: "公開", published: true, tag_list: "和食")
    users(:two).recipes.create!(title: "公開2", published: true, tag_list: "和食")
    users(:two).recipes.create!(title: "非公開", published: false, tag_list: "ひみつ")

    get tags_path
    assert_response :success
    assert_select "li", /#和食\s*\(2件\)/
    assert_select "li", text: /ひみつ/, count: 0
  end
end
