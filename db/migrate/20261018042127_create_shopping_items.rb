class CreateShoppingItems < ActiveRecord::Migration[8.1]
  def change
    create_table :shopping_items do |t|
      t.references :user, null: false, foreign_key: true
      # どのレシピから追加したか(手で追加したものは空。レシピが消えても項目は残す)
      t.references :recipe, null: true, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.string :quantity
      t.boolean :checked, null: false, default: false

      t.timestamps
    end
  end
end
