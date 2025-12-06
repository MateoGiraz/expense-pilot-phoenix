class AddUserEmailToAuditLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :audit_logs, :user_email, :string
  end
end
