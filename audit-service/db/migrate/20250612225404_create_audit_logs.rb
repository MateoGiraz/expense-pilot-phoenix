class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.string :action
      t.string :resource_type
      t.integer :resource_id
      t.json :data
      t.references :user, null: true, foreign_key: false
      t.references :company, null: true, foreign_key: false

      t.timestamps
    end
  end
end
