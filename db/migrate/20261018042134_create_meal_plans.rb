class CreateMealPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :slot, null: false, default: 0
      t.integer :servings

      t.timestamps
    end
    add_index :meal_plans, [ :user_id, :date ]
  end
end
