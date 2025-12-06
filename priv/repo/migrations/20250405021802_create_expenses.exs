defmodule ExpensePilot.Repo.Migrations.CreateExpenses do
  use Ecto.Migration

  def change do
    create table(:expenses) do
      add :amount, :decimal
      add :date, :date
      add :registered_at, :utc_datetime
      add :category_id, references(:categories, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :nothing)
      add :company_id, references(:companies, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:expenses, [:category_id])
    create index(:expenses, [:user_id])
    create index(:expenses, [:company_id])
  end
end
