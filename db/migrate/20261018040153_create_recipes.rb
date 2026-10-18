class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :cooking_minutes
      t.integer :servings
      t.boolean :published, null: false, default: false
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :recipes, [ :published, :deleted_at, :created_at ]
  end
end
