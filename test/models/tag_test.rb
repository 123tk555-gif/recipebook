require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "名前は必須で重複できない" do
    Tag.create!(name: "和食")
    assert_not Tag.new(name: "").valid?
    assert_not Tag.new(name: "和食").valid?
  end
end
