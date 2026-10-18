class AddFavoritesCountToRecipes < ActiveRecord::Migration[8.1]
  def change
    # 「お気に入りが多い順」の並べ替えのため、件数をレシピ側に持つ
    add_column :recipes, :favorites_count, :integer, null: false, default: 0
    add_index :recipes, :favorites_count
    add_index :recipes, :cooking_minutes
  end
end
