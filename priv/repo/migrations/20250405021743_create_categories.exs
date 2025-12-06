defmodule ExpensePilot.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string
      add :description, :text
      add :expense_limit, :decimal
      add :deleted, :boolean, default: false, null: false
      add :company_id, references(:companies, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:categories, [:company_id])
  end
end
