class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :recipe, null: false, foreign_key: true
      # 通報した会員・対応した管理者。退会しても通報の記録は残す
      t.references :reporter, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :handled_by, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :reason, null: false
      t.text :detail
      t.integer :status, null: false, default: 0
      t.datetime :handled_at

      t.timestamps
    end
    add_index :reports, [ :status, :created_at ]
  end
end
