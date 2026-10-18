# ゴミ箱に入れてから Recipe::TRASH_DAYS 日たったレシピを完全に削除する。
# 毎日 config/recurring.yml から実行される。
class PurgeTrashedRecipesJob < ApplicationJob
  queue_as :default

  def perform
    count = Recipe.expired.count
    Recipe.purge_expired
    Rails.logger.info("ゴミ箱の自動削除: #{count}件")
  end
end
