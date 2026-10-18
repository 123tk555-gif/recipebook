class AddModerationToRecipes < ActiveRecord::Migration[8.1]
  def change
    # 管理者が非公開にした日時(空なら通常どおり)。持ち主の「公開」設定とは別に持つ
    add_column :recipes, :hidden_at, :datetime
    # 退会した会員の公開レシピを残すため、作者を空にできるようにする
    change_column_null :recipes, :user_id, true
  end
end
