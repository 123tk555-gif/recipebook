require "test_helper"

class StepTest < ActiveSupport::TestCase
  test "手順の内容は必須で1000文字まで" do
    recipe = recipes(:public_one)
    assert_not recipe.steps.new(body: "").valid?
    assert_not recipe.steps.new(body: "あ" * 1001).valid?
    assert recipe.steps.new(body: "焼く").valid?
  end
end
