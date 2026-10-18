require "test_helper"

class PurgeTrashedRecipesJobTest < ActiveJob::TestCase
  test "30日たったレシピだけを削除する" do
    expired_id = recipes(:expired_one).id
    kept_id = recipes(:trashed_one).id

    assert_difference "Recipe.count", -1 do
      PurgeTrashedRecipesJob.perform_now
    end
    assert_not Recipe.exists?(expired_id)
    assert Recipe.exists?(kept_id)
  end

  test "毎日の定期実行に登録されている" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    assert_equal "PurgeTrashedRecipesJob", config.dig("production", "purge_trashed_recipes", "class")
  end
end
