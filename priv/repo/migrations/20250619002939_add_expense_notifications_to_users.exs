defmodule ExpensePilot.Repo.Migrations.AddExpenseNotificationsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :expense_notifications, :boolean, default: true, null: false
    end
  end
end
