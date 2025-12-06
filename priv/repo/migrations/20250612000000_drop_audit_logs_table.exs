defmodule ExpensePilot.Repo.Migrations.DropAuditLogsTable do
  use Ecto.Migration

  def change do
    drop_if_exists table(:audit_logs)
  end
end 