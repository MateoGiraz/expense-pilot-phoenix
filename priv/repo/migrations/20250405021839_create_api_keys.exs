defmodule ExpensePilot.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys) do
      add :name, :string
      add :key, :string
      add :user_id, references(:users, on_delete: :nothing)
      add :company_id, references(:companies, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:api_keys, [:user_id])
    create index(:api_keys, [:company_id])
  end
end
