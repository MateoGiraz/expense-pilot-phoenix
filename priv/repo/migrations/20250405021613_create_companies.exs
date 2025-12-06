defmodule ExpensePilot.Repo.Migrations.CreateCompanies do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :string
      add :address, :string
      add :website, :string
      add :logo, :string

      timestamps(type: :utc_datetime)
    end
  end
end
