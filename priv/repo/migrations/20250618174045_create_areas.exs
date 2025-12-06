defmodule ExpensePilot.Repo.Migrations.CreateAreas do
  use Ecto.Migration

  def change do
    create table(:areas) do
      add :name, :string, null: false
      add :description, :text
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:areas, [:company_id])
    create unique_index(:areas, [:name, :company_id])
  end
end
