class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.references :recipe, null: false, foreign_key: true
      t.string :name, null: false
      t.string :quantity
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
